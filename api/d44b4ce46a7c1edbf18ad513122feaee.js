import fs from 'fs';
import path from 'path';

export default function handler(req, res) {
  const userAgent = req.headers['user-agent'] || '';
  const isRoblox = userAgent.toLowerCase().includes('roblox');
  
  if (!isRoblox) {
    return res.status(403).send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Access Denied</title><style>body{background:#0a0e27;color:#e0e0e0;display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:Arial}.container{text-align:center}h1{color:#ff4444;font-size:48px}</style></head><body><div class="container"><h1>🛡️ Access Denied</h1><p>Roblox only</p></div></body></html>`);
  }
  
  try {
    let { id } = req.query;
    
    // Remove file extension if it has one (.js, .lua, etc)
    id = id.replace(/\.(js|lua)$/, '');
    
    // Try to read the .lua file
    const filePath = path.join(process.cwd(), 'public', 'files', 'v4', 'loaders', `${id}.lua`);
    const content = fs.readFileSync(filePath, 'utf-8');
    
    res.setHeader('Content-Type', 'text/plain');
    res.send(content);
  } catch (error) {
    res.status(404).send('Script not found');
  }
}