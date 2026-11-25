// Adds or updates the "Local SQL Server" profile in VS Code's settings.json.
// Run by lib/vscode.sh: osascript -l JavaScript vscode-connection.js <settings.json> <profile JSON>
// Prints "updated" or "unchanged".
ObjC.import('Foundation')
function run(argv) {
  const [path, profileJson] = argv
  const profile = JSON.parse(profileJson)
  const fm = $.NSFileManager.defaultManager
  const text = fm.fileExistsAtPath(path)
    ? $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js : ''
  // settings.json is JSONC (comments, trailing commas); a JS object literal accepts both.
  const settings = text.trim() ? Function('return (' + text + '\n)')() : {}
  const list = settings['mssql.connections'] || []
  const current = list.find(c => c.profileName === profile.profileName)
  if (current && JSON.stringify(current) === JSON.stringify(profile)) return 'unchanged'
  // Back up the original once; later runs must not overwrite it with our own edits.
  if (text.trim() && !fm.fileExistsAtPath(path + '.bak-sqlserver-setup')) $(text).writeToFileAtomicallyEncodingError(path + '.bak-sqlserver-setup', true, $.NSUTF8StringEncoding, null)
  settings['mssql.connections'] = [...list.filter(c => c.profileName !== profile.profileName), profile]
  // The extension drops connections whose groupId names no existing group.
  const groups = settings['mssql.connectionGroups'] || []
  if (!groups.some(g => g.id === 'ROOT')) settings['mssql.connectionGroups'] = [...groups, { name: 'ROOT', id: 'ROOT' }]
  $(JSON.stringify(settings, null, 2) + '\n').writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)
  return 'updated'
}
