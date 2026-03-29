export default function handler(req, res) {
  const userAgent = req.headers['user-agent'] || '';
  const isRoblox = userAgent.toLowerCase().includes('roblox');
  
  console.log('User-Agent:', userAgent);
  console.log('Is Roblox:', isRoblox);
  
  if (!isRoblox) {
    return res.status(403).send(`<!DOCTYPE html><html><head><title>Access Denied</title><style>body{background:#0a0e27;color:#e0e0e0;display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:Arial}.container{text-align:center}h1{color:#ff4444;font-size:48px}</style></head><body><div class="container"><h1>Access Denied</h1><p>Roblox only</p></div></body></html>`);
  }
  
  res.status(200).send('// Lua script here\nprint("loaded")');
}