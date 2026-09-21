const net = require("net");

const listenHost = process.env.LISTEN_HOST || "127.0.0.1";
const listenPort = Number(process.env.LISTEN_PORT || "443");
const relaySocket = process.env.RELAY_SOCKET;

if (!relaySocket) {
  console.error("RELAY_SOCKET missing");
  process.exit(2);
}

const server = net.createServer(client => {
  const upstream = net.createConnection({path: relaySocket});

  client.on("error", () => upstream.destroy());
  upstream.on("error", () => client.destroy());

  client.pipe(upstream);
  upstream.pipe(client);

  const close = () => {
    client.destroy();
    upstream.destroy();
  };
  client.on("close", close);
  upstream.on("close", close);
});

server.on("error", err => {
  console.error(err.message);
  process.exit(1);
});

server.listen(listenPort, listenHost, () => {
  process.stdout.write("READY\n");
});
