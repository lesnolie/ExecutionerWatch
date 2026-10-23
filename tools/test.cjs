const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const parse = require('luaparse');
process.chdir(path.resolve(__dirname, '..'));
const toc=fs.readFileSync('ExecutionerWatch/ExecutionerWatch.toc','utf8');
const version=(toc.match(/^## Version:\s*(\S+)\s*$/m)||[])[1];
if(!version) throw new Error('Main TOC has no Version field');
const expectedVersions=[
  ['package.json',JSON.parse(fs.readFileSync('package.json','utf8')).version],
  ['package-lock.json',JSON.parse(fs.readFileSync('package-lock.json','utf8')).version],
  ['ExecutionerProbe.toc',(fs.readFileSync('ExecutionerProbe/ExecutionerProbe.toc','utf8').match(/^## Version:\s*(\S+)\s*$/m)||[])[1]],
  ['Core.lua',(fs.readFileSync('ExecutionerWatch/Core.lua','utf8').match(/EW\.version[^=]*=\s*"([^"]+)"/)||[])[1]],
  ['ExecutionerProbe.lua',(fs.readFileSync('ExecutionerProbe/ExecutionerProbe.lua','utf8').match(/local VERSION[^=]*=\s*"([^"]+)"/)||[])[1]],
];
for(const [file,actual] of expectedVersions) {
  if(actual!==version) throw new Error(`${file} version ${actual||'<missing>'} does not match TOC ${version}`);
}
const files=toc.split(/\r?\n/).filter(x=>x.endsWith('.lua'));
for(const file of [...files.map(x=>'ExecutionerWatch/'+x),'ExecutionerProbe/ExecutionerProbe.lua']) {
  parse.parse(fs.readFileSync(file,'utf8'), {luaVersion:'5.1',scope:true});
}
console.log('Lua 5.1 syntax and .toc files: PASS');
console.log(`Version metadata: PASS (${version})`);
for (const [file,marker] of [['model','MODEL_TESTS_OK'],['settings','SETTINGS_TESTS_OK'],['integration','INTEGRATION_TESTS_OK'],['specialization','SPECIALIZATION_TESTS_OK'],['layout','LAYOUT_TESTS_OK'],['history','HISTORY_TESTS_OK'],['lifecycle','LIFECYCLE_TESTS_OK'],['probe','PROBE_TESTS_OK']]) {
  const run=spawnSync(process.execPath,[require.resolve('fengari-node-cli/src/lua-cli.js'),`tests/${file}.lua`],{encoding:'utf8'});
  process.stdout.write(run.stdout||'');
  if(run.stderr) process.stderr.write(run.stderr);
  // Fengari CLI can exit zero after a Lua error. Require the explicit terminal
  // success marker AND empty stderr, never just the process exit code.
  if(run.status!==0 || run.stderr || !run.stdout.includes(marker)) process.exit(1);
}
console.log('ALL_TESTS_OK');
