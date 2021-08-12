
export default [
  {
    file: 'chrome.json',
    name: 'Chrome',
    type: 'browser',
    version: '79.0.3945.130'
  },
  {
    file: 'firefox.json',
    name: 'Firefox',
    type: 'browser',
    version: '85.0.2',
    link: 'https://github.com/http-tests/cache-tests/wiki/Firefox'
  },
  {
    file: 'safari.json',
    name: 'Safari',
    type: 'browser',
    version: '14.0.3 (16610.4.3.1.4)'
  },
  {
    file: 'nginx.json',
    name: 'nginx',
    type: 'rev-proxy',
    version: '1.18.0-6ubuntu4',
    link: 'https://github.com/http-tests/cache-tests/wiki/nginx'
  },
  {
    file: 'squid.json',
    name: 'Squid',
    type: 'rev-proxy',
    version: '4.13-1ubuntu2',
    link: 'https://github.com/http-tests/cache-tests/wiki/Squid'
  },
  {
    file: 'trafficserver.json',
    name: 'ATS',
    type: 'rev-proxy',
    version: '8.1.1+ds-1',
    link: 'https://github.com/http-tests/cache-tests/wiki/Traffic-Server'
  },
  {
    file: 'ats-master.json',
    name: 'ATS-Master',
    type: 'rev-proxy',
    version: 'master',
    link: 'https://test.com'
  },
  {
    file: 'apache.json',
    name: 'httpd',
    type: 'rev-proxy',
    version: '2.4.46-2ubuntu1',
    link: 'https://github.com/http-tests/cache-tests/wiki/Apache-httpd'
  },
  {
    file: 'varnish.json',
    name: 'Varnish',
    type: 'rev-proxy',
    version: '6.5.1-1',
    link: 'https://github.com/http-tests/cache-tests/wiki/Varnish'
  },
  {
    file: 'nuster.json',
    name: 'nuster',
    type: 'rev-proxy',
    version: 'master',
    link: 'https://github.com/http-tests/cache-tests/wiki/nuster'
  },
  {
    file: 'fastly.json',
    name: 'Fastly',
    type: 'cdn',
    version: '06-05-2019',
    link: 'https://github.com/http-tests/cache-tests/wiki/Fastly'
  }
]
