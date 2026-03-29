export function middleware(request) {
  const url = new URL(request.url);
  
  // Only intercept /files/v4/loaders/*.lua requests
  if (url.pathname.match(/^\/files\/v4\/loaders\/.*\.lua$/)) {
    const userAgent = request.headers.get('user-agent') || '';
    
    // Check if request is from Roblox
    const isRoblox = userAgent.includes('Roblox');
    
    if (!isRoblox) {
      // Return access denied page
      return new Response(`
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
      `, {
        status: 403,
        headers: { 'Content-Type': 'text/html' }
      });
    }
  }
  
  // Allow Roblox requests or non-Lua files to pass through
  return undefined;
}
