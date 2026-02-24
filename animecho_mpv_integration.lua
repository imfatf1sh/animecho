-- tweak these values basing on your needs

ANIMECHO_APP_ADDR = '127.0.0.1'  -- currently only IPv4 and no DNS resolutions
ANIMECHO_APP_PORT = 22206

ANIMECHO_UPDATE_INTERVAL_SECS = 1  -- no smaller than 0.05 due to mpv limitation

if jit == nil then
  mp.msg.warn('Your MPV was not compiled with LuaJIT support, this script cannot work.')
  exit()  -- tells Mpv to not run event loop for us
  goto bottom
end

-- known to work on linux and android for now
if jit.os ~= 'Linux' then
  mp.msg.warn(string.format('Only Linux is supported, you are on %s.', jit.os))
  exit(); goto bottom
end

if jit.arch ~= 'x64' then
  mp.msg.warn(string.format('This script is not ready for %s machines yet.', jit.arch))
  exit(); goto bottom
end

ffi = require('ffi')

-- arpa/inet.h errno.h netinet/in.h sys/socket.h unistd.h

AF_INET = 2
ECONNREFUSED = 111
IPPROTO_UDP = 17
SOCK_DGRAM = 2
SOCK_NONBLOCK = 0x800

ffi.cdef[[
  typedef uint32_t in_addr_t;
  typedef uint16_t in_port_t;
  typedef unsigned short sa_family_t;
  typedef unsigned int socklen_t;

  struct in_addr {
    in_addr_t s_addr;
  };

  struct sockaddr_in {
    sa_family_t sin_family;
    in_port_t sin_port;
    struct in_addr sin_addr;
    unsigned char sin_zero[8];
  };

  int close(int fildes);
  int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
  uint32_t htonl(uint32_t hostlong);
  uint16_t htons(uint16_t hostshort);
  int inet_aton(const char *cp, struct in_addr *inp);
  int socket(int domain, int type, int protocol);
  ssize_t write(int fd, const void *buf, size_t count);
]]

-- setup network
do
  local serveraddr = ffi.new('struct sockaddr_in')

  if ffi.C.inet_aton(ANIMECHO_APP_ADDR, serveraddr.sin_addr) == 0 then
    mp.msg.error(string.format('Failed to parse \'%s\' as an IPv4 address.', ANIMECHO_APP_ADDR))
    exit(); goto bottom
  end

  fd = ffi.C.socket(AF_INET, bit.bor(SOCK_DGRAM, SOCK_NONBLOCK), IPPROTO_UDP);
  if fd < 0 then
    mp.msg.error(string.format('Unable to create UDP socket, error %d.', ffi.errno()))
    exit(); goto bottom
  end

  serveraddr.sin_port = ffi.C.htons(ANIMECHO_APP_PORT)
  serveraddr.sin_family = AF_INET

  function animecho_cleanup() ffi.C.close(fd) end

  -- do this so we don't have to pass the address every time.
  if ffi.C.connect(fd, ffi.cast('struct sockaddr *', serveraddr), ffi.sizeof('struct sockaddr_in')) < 0 then
    mp.msg.error(string.format('Failed to set destination on socket, error %d.', ffi.errno()))
    animecho_cleanup(); exit(); goto bottom
  end
end

mp.register_event('shutdown', animecho_cleanup)

buff = ffi.new('unsigned int[1]')

function animecho_do_work()
  local t = mp.get_property_number('time-pos/full', 0)

  buff[0] = ffi.C.htonl(math.floor(t * 1000))  -- to milliseconds
  local n = ffi.C.write(fd, buff, ffi.sizeof('unsigned int'))

  if n < 0 then
    local err = ffi.errno()
    if err == ECONNREFUSED then
      -- XXX: side effects of connect(2). for now, just continue retrying.
    else
      mp.msg.error(string.format('Failed to send packet, error %d.', err))
      animecho_cleanup(); exit()  -- give up
    end
  elseif n < ffi.sizeof('unsigned int') then
    mp.msg.warn(string.format('Couldn\'t fully send packet, %d out of %d bytes sent.', n, ffi.sizeof('unsigned int')))
  end
end

mp.add_periodic_timer(ANIMECHO_UPDATE_INTERVAL_SECS, animecho_do_work)

mp.msg.info('Finished script initialization.')

::bottom::
