const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 8080;

const wss = new WebSocket.Server({ server, path: '/ws' });

let messages = [];
const MAX_MESSAGES = 40;

app.use(express.json());

app.get('/', (req, res) => {
    res.send('Сервер kChat запущен и должен работать');
});

app.post('/send', (req, res) => {
    const { userId, name, text } = req.body;
    if (!userId || !name || !text) return res.status(400).json({ error: 'Missing fields' });
    if (text.length < 90) {
        const msg = { id: Date.now(), userId, name, text, timestamp: new Date().toISOString() };
        messages.push(msg);
        if (messages.length > MAX_MESSAGES) messages.shift();
        broadcast(JSON.stringify({ type: 'new_message', ...msg }));
        res.json({ success: true });
        console.log(`${name}: ${text}`);
    }  else {
        return res.status(400).json({ error: 'Слишком длинное сообщение' });
    }
});

app.get('/messages', (req, res) => {
    const since = parseInt(req.query.since) || 0;
    const newMessages = messages.filter(m => m.id > since);
    res.json({ messages: newMessages, serverTime: Date.now() });
});

app.post('/join', (req, res) => {
    const { userId, name } = req.body;
    if (!userId || !name) return res.status(400).json({ error: 'Missing fields' });
    const msg = { id: Date.now(), userId: 'system', name: 'System', text: `${name}, дарова!`, timestamp: new Date().toISOString() };
    messages.push(msg);
    if (messages.length > MAX_MESSAGES) messages.shift();
    broadcast(JSON.stringify({ type: 'new_message', ...msg }));
    res.json({ success: true });
});

const clients = new Map();

wss.on('connection', (ws, req) => {
    ws.on('message', (data) => {
        try {
            const msg = JSON.parse(data);
            if (msg.type === 'auth') {
                clients.set(ws, { userId: msg.userId, name: msg.name });
                const joinMsg = { id: Date.now(), userId: 'system', name: 'System', text: `${msg.name} присоединился`, timestamp: new Date().toISOString() };
                messages.push(joinMsg);
                broadcast(JSON.stringify({ type: 'new_message', ...joinMsg }));
            } else if (msg.type === 'chat') {
                const sender = clients.get(ws);
                if (sender) {
                    const chatMsg = { id: Date.now(), userId: sender.userId, name: sender.name, text: msg.text, timestamp: new Date().toISOString() };
                    messages.push(chatMsg);
                    broadcast(JSON.stringify({ type: 'new_message', ...chatMsg }));
                }
            }
        } catch (e) {
            console.error('ошибка:', e);
        }
    });

    ws.on('close', () => {
        const sender = clients.get(ws);
        if (sender) {
            const leaveMsg = { id: Date.now(), userId: 'system', name: 'System', text: `${sender.name} отключился`, timestamp: new Date().toISOString() };
            messages.push(leaveMsg);
            broadcast(JSON.stringify({ type: 'new_message', ...leaveMsg }));
            clients.delete(ws);
        }
    });
});

function broadcast(payload) {
    for (const [client] of clients) {
        if (client.readyState === WebSocket.OPEN) {
            client.send(payload);
        }
    }
}

server.listen(PORT, () => {
    console.log(`порт: ${PORT}`);
});
