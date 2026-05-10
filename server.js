const express = require('express');
const app = express();
const http = require('http').createServer(app);
const PORT = process.env.PORT || 8080;

app.use(express.json());

let messages = [];
const MAX = 100;
const users = {};

app.post('/send', (req, res) => {
    const { userId, name, text } = req.body;
    if (!userId || !name || !text) return res.status(400).json({ error: 'Missing fields' });
    users[userId] = name;
    const msg = { id: Date.now(), userId, name, text, timestamp: new Date().toISOString() };
    messages.push(msg);
    if (messages.length > MAX) messages.shift();
    res.json({ success: true });
});

app.get('/messages', (req, res) => {
    const since = parseInt(req.query.since) || 0;
    const newMsgs = messages.filter(m => m.id > since);
    res.json({ messages: newMsgs, serverTime: Date.now() });
});

app.post('/join', (req, res) => {
    const { userId, name } = req.body;
    if (!userId || !name) return res.status(400).json({ error: 'Missing fields' });
    users[userId] = name;
    const msg = { id: Date.now(), userId: 'system', name: 'System', text: `${name} присоединился`, timestamp: new Date().toISOString() };
    messages.push(msg);
    if (messages.length > MAX) messages.shift();
    res.json({ success: true });
});

http.listen(PORT, () => console.log(`HTTP server on port ${PORT}`));
