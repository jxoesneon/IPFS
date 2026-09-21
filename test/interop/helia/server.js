import express from "express";
import fs from "node:fs";
import { createHelia } from "helia";
import { identify, identifyPush } from "@libp2p/identify";
import { ping } from "@libp2p/ping";
import { gossipsub } from "@chainsafe/libp2p-gossipsub";
import { preSharedKey } from "@libp2p/pnet";
import { strings } from "@helia/strings";
import { car } from "@helia/car";
import { CarReader } from "@ipld/car";
import { CID } from "multiformats/cid";
import { multiaddr } from "@multiformats/multiaddr";

const app = express();
const port = process.env.PORT || 5001;
const libp2pPort = process.env.LIBP2P_PORT || 4001;
const swarmKeyPath = process.env.SWARM_KEY || "/swarm.key";

let heliaInstance;

async function getHelia() {
  if (!heliaInstance) {
    // Pass libp2p *options* (not an instance) so Helia merges them over its
    // own version-consistent defaults. Default Helia has no pubsub service
    // and no pnet; the interop network needs both. Replacing `services`
    // wholesale, so identify/ping are kept explicitly.
    const libp2pOptions = {
      addresses: {
        listen: [`/ip4/0.0.0.0/tcp/${libp2pPort}`],
      },
      services: {
        identify: identify(),
        identifyPush: identifyPush(),
        ping: ping(),
        pubsub: gossipsub({ emitSelf: false }),
      },
    };

    if (fs.existsSync(swarmKeyPath)) {
      // preSharedKey expects the raw swarm.key file bytes; it decodes the
      // /key/swarm/psk/1.0.0/ + /base16/ envelope itself.
      libp2pOptions.connectionProtector = preSharedKey({
        psk: fs.readFileSync(swarmKeyPath),
      });
      console.log("pnet enabled from", swarmKeyPath);
    } else {
      console.warn("no swarm key found; running without pnet");
    }

    heliaInstance = await createHelia({ libp2p: libp2pOptions });
  }
  return heliaInstance;
}

function getSingleStringArg(queryArg) {
  if (!queryArg) return null;
  if (typeof queryArg === "string") return queryArg.trim();
  if (Array.isArray(queryArg) && queryArg.length > 0 && typeof queryArg[0] === "string") {
    return queryArg[0].trim();
  }
  return null;
}

function toMultibaseBase64url(bytes) {
  return "u" + Buffer.from(bytes).toString("base64url");
}

// Kubo-style arg decoding: pubsub topic args arrive as multibase base64url
// ("u" prefix). Decode them, but only if the value round-trips exactly — a
// literal topic that merely starts with "u" must not be mangled.
function decodeTopicArg(arg) {
  if (typeof arg === "string" && arg.length > 1 && arg.startsWith("u")) {
    try {
      const decoded = Buffer.from(arg.slice(1), "base64url");
      if (toMultibaseBase64url(decoded) === arg) {
        return decoded.toString("utf8");
      }
    } catch {
      // Not valid multibase base64url; treat as a literal topic name.
    }
  }
  return arg;
}

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.post("/api/v0/id", async (req, res) => {
  try {
    const helia = await getHelia();
    const peerId = helia.libp2p.peerId.toString();
    const multiaddrs = helia.libp2p.getMultiaddrs().map((ma) => ma.toString());
    res.json({
      ID: peerId,
      Addresses: multiaddrs,
      AgentVersion: "helia/5.0.0",
      Protocols: [],
    });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.post("/api/v0/version", async (req, res) => {
  res.json({
    Version: "helia/5.0.0",
    Commit: "",
    Repo: "fs-repo",
    System: "node",
    Golang: "",
  });
});

app.post("/api/v0/swarm/connect", async (req, res) => {
  const target = getSingleStringArg(req.query.arg);
  if (!target) {
    return res.status(400).json({ Error: "Missing or invalid arg query parameter" });
  }
  try {
    const helia = await getHelia();
    await helia.libp2p.dial(multiaddr(target), {
      signal: AbortSignal.timeout(30000),
    });
    res.json({ Strings: [`connect ${target} success`] });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

// POST /api/v0/pubsub/pub?arg=<topic> — body is the raw message payload.
app.post(
  "/api/v0/pubsub/pub",
  express.raw({ type: () => true, limit: "1mb" }),
  async (req, res) => {
    const topic = decodeTopicArg(getSingleStringArg(req.query.arg));
    if (!topic) {
      return res.status(400).json({ Error: "Missing or invalid arg query parameter" });
    }
    try {
      const helia = await getHelia();
      const result = await helia.libp2p.services.pubsub.publish(
        topic,
        new Uint8Array(req.body),
      );
      res.json({ Recipients: result.recipients.map((p) => p.toString()) });
    } catch (err) {
      res.status(500).json({ Error: err.message });
    }
  },
);

// POST /api/v0/pubsub/sub?arg=<topic> — subscribe and stream NDJSON
// messages in the Kubo wire shape until the client disconnects.
app.post("/api/v0/pubsub/sub", async (req, res) => {
  const topic = decodeTopicArg(getSingleStringArg(req.query.arg));
  if (!topic) {
    return res.status(400).json({ Error: "Missing or invalid arg query parameter" });
  }
  try {
    const helia = await getHelia();
    const pubsub = helia.libp2p.services.pubsub;
    pubsub.subscribe(topic);

    res.setHeader("Content-Type", "application/json");
    res.setHeader("X-Chunked-Output", "1");
    res.flushHeaders();

    const onMessage = (evt) => {
      const msg = evt.detail;
      if (msg.topic !== topic) return;
      const line = JSON.stringify({
        from: msg.from?.toString() ?? "",
        data: toMultibaseBase64url(msg.data ?? new Uint8Array(0)),
        seqno:
          msg.sequenceNumber != null
            ? toMultibaseBase64url(
                typeof msg.sequenceNumber === "bigint"
                  ? (() => {
                      const b = new Uint8Array(8);
                      new DataView(b.buffer).setBigUint64(0, msg.sequenceNumber);
                      return b;
                    })()
                  : new Uint8Array(msg.sequenceNumber),
              )
            : "u",
        topicIDs: [toMultibaseBase64url(Buffer.from(msg.topic, "utf8"))],
      });
      res.write(line + "\n");
    };
    pubsub.addEventListener("message", onMessage);
    req.on("close", () => {
      pubsub.removeEventListener("message", onMessage);
      res.end();
    });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

// POST /api/v0/pubsub/ls — subscribed topics.
app.post("/api/v0/pubsub/ls", async (req, res) => {
  try {
    const helia = await getHelia();
    res.json({ Strings: helia.libp2p.services.pubsub.getTopics() });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

// POST /api/v0/pubsub/peers?arg=<topic> — peers subscribed to the topic.
app.post("/api/v0/pubsub/peers", async (req, res) => {
  const topic = decodeTopicArg(getSingleStringArg(req.query.arg));
  try {
    const helia = await getHelia();
    const peers = topic
      ? helia.libp2p.services.pubsub.getSubscribers(topic)
      : [];
    res.json({ Strings: peers.map((p) => p.toString()) });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.post(
  "/api/v0/add",
  express.raw({ type: () => true, limit: "100mb" }),
  async (req, res) => {
    if (
      typeof req.body !== "object" ||
      req.body === null ||
      Array.isArray(req.body)
    ) {
      return res.status(400).json({ Error: "Request body must be raw bytes" });
    }
    try {
      const helia = await getHelia();
      const s = strings(helia);
      const text = req.body.toString("utf8");
      const cid = await s.add(text);
      res.json({
        Hash: cid.toString(),
        Name: cid.toString(),
        Size: req.body.length,
      });
    } catch (err) {
      res.status(500).json({ Error: err.message });
    }
  },
);

app.get("/api/v0/cat", async (req, res) => {
  const cidStr = getSingleStringArg(req.query.arg);
  if (!cidStr) {
    return res.status(400).json({ Error: "Missing or invalid arg query parameter" });
  }
  try {
    const helia = await getHelia();
    const s = strings(helia);
    const text = await s.get(CID.parse(cidStr));
    res.send(text);
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.get("/api/v0/dag/export", async (req, res) => {
  const cidStr = getSingleStringArg(req.query.arg);
  if (!cidStr) {
    return res.status(400).json({ Error: "Missing or invalid arg query parameter" });
  }
  try {
    const helia = await getHelia();
    const c = car(helia);
    res.setHeader("Content-Type", "application/vnd.ipld.car");
    for await (const chunk of c.stream(CID.parse(cidStr))) {
      res.write(chunk);
    }
    res.end();
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.post(
  "/api/v0/dag/import",
  express.raw({ type: () => true, limit: "100mb" }),
  async (req, res) => {
    if (
      typeof req.body !== "object" ||
      req.body === null ||
      Array.isArray(req.body)
    ) {
      return res.status(400).json({ Error: "Request body must be raw bytes" });
    }
    try {
      const helia = await getHelia();
      const c = car(helia);
      const reader = await CarReader.fromBytes(new Uint8Array(req.body));
      await c.import(reader);
      res.json({ Status: "success" });
    } catch (err) {
      res.status(500).json({ Error: err.message });
    }
  },
);

async function main() {
  await getHelia();
  app.listen(port, "0.0.0.0", () => {
    console.log(`Helia interop server listening on port ${port}`);
  });
}

main().catch((err) => {
  console.error("Failed to start Helia server:", err);
  process.exit(1);
});
