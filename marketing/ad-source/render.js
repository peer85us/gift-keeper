const puppeteer = require('puppeteer-core');
const [,, html, outDir, fpsArg, durArg, only] = process.argv;
const fps = +fpsArg, dur = +durArg;
(async () => {
  const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new', args: ['--allow-file-access-from-files'] });
  const p = await b.newPage(); await p.setViewport({ width: 1080, height: 1920 });
  await p.goto('file://' + html, { waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 500));
  const times = only ? only.split(',').map(Number) : Array.from({ length: Math.round(fps * dur) }, (_, i) => i / fps);
  for (let i = 0; i < times.length; i++) {
    await p.evaluate(t => window.seek(t), times[i]);
    await p.screenshot({ path: `${outDir}/f${String(i).padStart(4, '0')}.jpg`, type: 'jpeg', quality: 92 });
  }
  await b.close();
})();
