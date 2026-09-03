import express from "express";
import { createHelia } from "helia";
import { strings } from "@helia/strings";
import { car } from "@helia/car";
import { CID } from "multiformats/cid";

const app = express();
const port = process.env.PORT || 5001;

let heliaInstance;

async function getHelia() {
  if (!heliaInstance) {
    heliaInstance = await createHelia();
  }
  return heliaInstance;
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
  const target = req.query.arg;
  if (!target) {
    return res.status(400).json({ Error: "Missing arg query parameter" });
  }
  try {
    const helia = await getHelia();
    await helia.libp2p.dial(target);
    res.json({ Strings: [`connect ${target} success`] });
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.post(
  "/api/v0/add",
  express.raw({ type: "*/*", limit: "100mb" }),
  async (req, res) => {
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
  const cidStr = req.query.arg;
  if (!cidStr) {
    return res.status(400).json({ Error: "Missing arg query parameter" });
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
  const cidStr = req.query.arg;
  if (!cidStr) {
    return res.status(400).json({ Error: "Missing arg query parameter" });
  }
  try {
    const helia = await getHelia();
    const c = car(helia);
    const writer = await c.export(CID.parse(cidStr));
    res.setHeader("Content-Type", "application/vnd.ipld.car");
    for await (const chunk of writer) {
      res.write(chunk);
    }
    res.end();
  } catch (err) {
    res.status(500).json({ Error: err.message });
  }
});

app.post(
  "/api/v0/dag/import",
  express.raw({ type: "*/*", limit: "100mb" }),
  async (req, res) => {
    try {
      const helia = await getHelia();
      const c = car(helia);
      await c.import(req.body);
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
