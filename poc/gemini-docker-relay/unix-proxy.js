const net = require("net");
const sock = process.env.RELAY_SOCKET;
if (!sock) { console.error("RELAY_SOCKET missing"); process.exit(2); }
const c = net.createConnection({path: sock});
c.on("connect", () => {
  process.stdin.pipe(c);
  c.pipe(process.stdout);
});
c.on("error", e => { console.error(e.message); process.exit(1); });
process.stdin.on("error", () => {});
process.stdout.on("error", () => {});
