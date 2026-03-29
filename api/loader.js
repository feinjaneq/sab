import { readFileSync } from 'fs';
import { join } from 'path';

export default function handler(req, res) {
  const userAgent = req.headers['user-agent'] || '';
  
  // Check if request is from Roblox
  const isRoblox = userAgent.includes('Roblox');
  
  if (!isRoblox) {
    // Return access denied page for non-Roblox requests
    return res.status(403).send(`
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Access Denied</title>
  <style>
    body {
      background: #0a0e27;
      color: #e0e0e0;
      font-family: Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }
    .container { text-align: center; max-width: 600px; }
    h1 { font-size: 48px; color: #ff4444; margin-bottom: 10px; }
    p { font-size: 18px; color: #999; margin-bottom: 30px; }
    .box { background: rgba(255,68,68,0.1); border: 2px solid #ff4444; border-radius: 8px; padding: 20px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🛡️ Access Denied</h1>
    <p>Unauthorized Access Attempt Detected</p>
    <div class="box">
      <h2>Access Restricted</h2>
      <p>This endpoint is protected and can only be accessed through authorized Roblox game servers.</p>
    </div>
  </div>
</body>
</html>
    `);
  }

  try {
    // Get the script ID from URL
    const scriptId = req.query.script;
    
    // Read the Lua file
    const luaPath = join(process.cwd(), 'public', 'files', 'v4', 'loaders', `${scriptId}.lua`);
    const luaScript = readFileSync(luaPath, 'utf-8');
    
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.status(200).send(luaScript);
  } catch (error) {
    res.status(404).send('Script not found');
  }
}