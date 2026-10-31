import urllib.request,json
url='https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable'
try:
 data=json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'ScrapDragon-build-research'}),timeout=30))
 for a in data.get('assets',[]):
  if 'template' in a['name'] or 'android' in a['name']:print(a['name'],a['size'],a['browser_download_url'])
except Exception as e:print('Cannot retrieve official matching Gradle template:',e)
url='https://api.github.com/repos/poingstudios/godot-admob-plugin/releases/tags/v5.1.0'
try:
 data=json.load(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'ScrapDragon-build-research'}),timeout=30))
 for a in data.get('assets',[]):print(a['name'],a['size'],a['browser_download_url'])
except Exception as e:print('Cannot retrieve AdMob release:',e)
