import { createHelia } from "helia";
import { identify, identifyPush } from "@libp2p/identify";
import { ping } from "@libp2p/ping";
import { gossipsub } from "@chainsafe/libp2p-gossipsub";
import { preSharedKey } from "@libp2p/pnet";
import { multiaddr } from "@multiformats/multiaddr";
import { readFileSync } from "node:fs";

const target = process.argv[2];
const swarmKey = readFileSync("/home/eduardo/IPFS/test/interop/swarm.key");
const helia = await createHelia({
  libp2p: {
    addresses: { listen: ["/ip4/127.0.0.1/tcp/14061"] },
    connectionProtector: preSharedKey({ psk: swarmKey }),
    services: {
      identify: identify(),
      identifyPush: identifyPush(),
      ping: ping(),
      pubsub: gossipsub({ emitSelf: false }),
    },
  },
});
console.log("helia peer:", helia.libp2p.peerId.toString());
const conn = await helia.libp2p.dial(multiaddr(target), { signal: AbortSignal.timeout(15000) });
console.log("connected to", conn.remotePeer.toString());
await new Promise(r => setTimeout(r, 4000));
const peer = await helia.libp2p.peerStore.get(conn.remotePeer);
console.log("dart protocols:", peer.protocols);
console.log("pubsub peers:", [...helia.libp2p.services.pubsub.peers].map(p=>p.toString()));
helia.libp2p.services.pubsub.subscribe("interop-test");
await new Promise(r => setTimeout(r, 3000));
console.log("after subscribe, topic peers:", [...helia.libp2p.services.pubsub.getSubscribers("interop-test")].map(p=>p.toString()));
await helia.stop();
process.exit(0);
