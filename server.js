const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

const clients = new Map(); // ws -> { userId, name }

wss.on('connection', (ws) => {
    ws.on('message', (data) => {
        const msg = JSON.parse(data);
        if (msg.type === 'auth') {
            clients.set(ws, { userId: msg.userId, name: msg.name });
            broadcast({ type: 'system', text: `${msg.name} joined` });
        } else if (msg.type === 'chat') {
            const sender = clients.get(ws);
            broadcast({ type: 'chat', name: sender.name, text: msg.text });
        }
    });
    ws.on('close', () => {
        const sender = clients.get(ws);
        if (sender) {
            broadcast({ type: 'system', text: `${sender.name} left` });
            clients.delete(ws);
        }
    });
});

function broadcast(data) {
    const payload = JSON.stringify(data);
    for (const [ws] of clients) {
        ws.send(payload);
    }
}
