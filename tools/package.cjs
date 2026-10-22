const {spawnSync}=require('node:child_process');
const path=require('node:path');
process.chdir(path.resolve(__dirname,'..'));
for(const file of ['tools/test.cjs','tools/preview.cjs']){
  const r=spawnSync(process.execPath,[file],{stdio:'inherit'});
  if(r.status!==0) process.exit(r.status||1);
}
const r=spawnSync('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.resolve('tools/package.ps1')],{stdio:'inherit'});
if(r.error) console.error(r.error.message);
process.exit(r.status===0?0:(r.status||1));
