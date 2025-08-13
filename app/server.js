const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>❄️ Node.js on EKS - Ice Cold! ❄️</title>
      <style>
        body {
          background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
          color: #e0f7fa;
          font-family: 'Segoe UI', Arial, sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          overflow: hidden;
        }
        .snow {
          position: absolute;
          top: 0;
          left: 0;
          width: 100vw;
          height: 100vh;
          pointer-events: none;
          z-index: 0;
        }
        h1 {
          font-size: 3rem;
          margin-bottom: 0.5rem;
          text-shadow: 0 0 20px #00eaff, 0 0 40px #1e90ff;
          letter-spacing: 2px;
        }
        p {
          font-size: 1.5rem;
          margin-bottom: 2rem;
        }
        .card {
          background: rgba(0,30,60,0.25);
          border-radius: 20px;
          padding: 2.5rem 3.5rem;
          box-shadow: 0 8px 32px 0 rgba(30, 60, 150, 0.37);
          text-align: center;
          position: relative;
          z-index: 1;
          animation: glow 2s infinite alternate;
        }
        @keyframes glow {
          0% { box-shadow: 0 8px 32px 0 rgba(30, 60, 150, 0.37); }
          100% { box-shadow: 0 8px 64px 0 #00eaff88; }
        }
        .btn {
          background: #e0f7fa;
          color: #1e3c72;
          border: none;
          border-radius: 8px;
          padding: 0.75rem 2rem;
          font-size: 1.1rem;
          cursor: pointer;
          transition: background 0.2s, color 0.2s, box-shadow 0.2s;
          box-shadow: 0 2px 8px 0 #00eaff44;
        }
        .btn:hover {
          background: #1e3c72;
          color: #e0f7fa;
          box-shadow: 0 4px 16px 0 #00eaff88;
        }
        .flake {
          position: absolute;
          top: 0;
          border-radius: 50%;
          background: linear-gradient(180deg, #fff, #e0f7fa 80%, #b3e5fc 100%);
          opacity: 0.8;
          pointer-events: none;
          z-index: 2;
          box-shadow: 0 0 8px #fff, 0 0 16px #b3e5fc;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>❄️ Node.js on EK ❄️</h1>
        <p>Your cloud-native app is running cool and smooth on <b>AWS EKS</b>!</p>
        <a href="https://aws.amazon.com/eks/" target="_blank" class="btn">Learn more about EKS</a>
      </div>
      <div class="snow" id="snow"></div>
      <script>
        // Generate animated snowflakes
        const snow = document.getElementById('snow');
        const flakes = [];
        for (let i = 0; i < 50; i++) {
          const flake = document.createElement('div');
          flake.className = 'flake';
          flake.style.left = (Math.random() * 100) + 'vw';
          flake.style.width = flake.style.height = (8 + Math.random() * 16) + 'px';
          flake.style.opacity = 0.6 + Math.random() * 0.4;
          flake.style.top = (-20 - Math.random() * 100) + 'px';
          snow.appendChild(flake);
          flakes.push({el: flake, speed: 1 + Math.random() * 2, drift: (Math.random() - 0.5) * 0.5});
        }
        function animateSnow() {
          flakes.forEach(flake => {
            let top = parseFloat(flake.el.style.top);
            let left = parseFloat(flake.el.style.left);
            top += flake.speed;
            left += flake.drift;
            if (top > window.innerHeight) {
              top = -20;
              left = Math.random() * window.innerWidth;
            }
            flake.el.style.top = top + 'px';
            flake.el.style.left = left + 'px';
          });
          requestAnimationFrame(animateSnow);
        }
        animateSnow();
      </script>
    </body>
    </html>
  `);
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
