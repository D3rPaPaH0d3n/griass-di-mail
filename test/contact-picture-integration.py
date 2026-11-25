#!/usr/bin/python3
# Copyright 2026 Markus Kainer <projekt@kainer.co.at>
# SPDX-License-Identifier: GPL-3.0-only
# Real client-library/GTK/HTTPS fixtures; run ONLY through the isolated test runner.
import os
from pathlib import Path
assert os.environ.get('GSETTINGS_BACKEND') == 'memory'
assert os.environ.get('GRIABUNTU_SYNTHETIC_NETWORK') == '1'
interfaces=[line.split(':')[0].strip() for line in Path('/proc/net/dev').read_text().splitlines() if ':' in line]
assert interfaces == ['lo'], 'A private loopback-only network namespace is required'
build=Path(os.environ['GRIABUNTU_TEST_BUILD'])
certificate=os.environ['GRIABUNTU_TEST_CERT']
key=os.environ['GRIABUNTU_TEST_KEY']
import gi,ctypes,ssl,threading,time,socket,select
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
gi.require_version('Gtk','4.0');gi.require_version('Adw','1');gi.require_version('GdkPixbuf','2.0')
from gi.repository import Gtk,Adw,Gio,GLib,GdkPixbuf
Gtk.init();Adw.init()
image=GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB,True,8,4,4);image.fill(0x33aa88ff)
_,png=image.save_to_bufferv('png',[],[])
requests=[];connections=[];mode='fallback'
class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  requests.append((self.path,dict(self.headers)))
  if mode=='fallback' and self.path.startswith('/avatar/'):
   self.send_response(404);self.end_headers();return
  if mode=='redirect':
   self.send_response(302);self.send_header('Location','https://attacker.invalid/tracker');self.end_headers();return
  body=b'<svg xmlns="http://www.w3.org/2000/svg"/>' if mode=='svg' else png
  if mode=='oversized':body=b'x'*600000
  if mode=='delayed':time.sleep(.4)
  self.send_response(200);self.send_header('Content-Type','image/png');self.send_header('Content-Length',str(len(body)));self.end_headers()
  try:self.wfile.write(body)
  except (BrokenPipeError,ssl.SSLError):pass
class Proxy(BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_CONNECT(self):
  connections.append(self.path)
  assert self.path in ('www.gravatar.com:443','icons.duckduckgo.com:443'),self.path
  upstream=socket.create_connection(('127.0.0.1',8443))
  self.send_response(200);self.end_headers()
  try:
   while True:
    ready,_,_=select.select([self.connection,upstream],[],[],8)
    if not ready:break
    for current in ready:
     data=current.recv(16384)
     if not data:return
     (upstream if current is self.connection else self.connection).sendall(data)
  except (ConnectionResetError,BrokenPipeError):pass
  finally:upstream.close()
proxy=ThreadingHTTPServer(('127.0.0.1',18080),Proxy)
threading.Thread(target=proxy.serve_forever,daemon=True).start()
server=ThreadingHTTPServer(('127.0.0.1',8443),Handler)
ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(certificate,key)
server.socket=ctx.wrap_socket(server.socket,server_side=True)
threading.Thread(target=server.serve_forever,daemon=True).start()
library=os.environ.get('GRIABUNTU_TEST_LIBRARY',str(build/'src/client/libgriabuntu-mail-client-51.0.so'))
lib=ctypes.CDLL(library)
def function(name,args,result):
 f=getattr(lib,name);f.argtypes=args;f.restype=result;return f
ptr=ctypes.c_void_p;string=ctypes.c_char_p
new_config=function('application_configuration_new',[string],ptr)
new_mailbox=function('griabuntu_mail_rf_c822_mailbox_address_new',[string,string],ptr)
new_picture=function('application_contact_picture_new',[ptr,ptr,ptr,ptr],ptr)
close=function('application_contact_picture_close',[ptr],None)
capsule=ctypes.pythonapi.PyCapsule_GetPointer;capsule.argtypes=[ctypes.py_object,string];capsule.restype=ptr
settings=Gio.Settings.new('io.github.d3rpapah0d3n.GriabuntuMail')
settings.set_boolean('remote-contact-pictures',False);settings.set_boolean('company-pictures',False)
settings.set_string('proxy-uri','http://127.0.0.1:18080');settings.set_boolean('custom-proxy',True)
config=new_config(b'io.github.d3rpapah0d3n.GriabuntuMail')
window=Adw.Window(default_width=200,default_height=200);avatar=Adw.Avatar(size=48,text='Synthetic')
window.set_content(avatar);window.present()
def pump(seconds):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  while GLib.MainContext.default().pending():GLib.MainContext.default().iteration(False)
  time.sleep(.005)
def controller(address):
 mailbox=new_mailbox(b'Synthetic',address.encode())
 return new_picture(capsule(avatar.__gpointer__,None),None,mailbox,config)
pump(.1)
picture=controller('person@company.com');pump(.15)
assert len(requests)==0,'requests before consent'
print('PASS no network before consent')
settings.set_boolean('remote-contact-pictures',True);pump(.5)
assert len(requests)==1 and requests[0][0].startswith('/avatar/'),str(requests)
assert avatar.get_custom_image() is None
print('PASS personal consent alone: Gravatar only, 404 keeps initials')
settings.set_boolean('company-pictures',True);pump(.5)
assert requests[-1][0]=='/ip3/company.com.ico',str(requests)
assert avatar.get_custom_image() is not None,'no company image displayed'
assert all('person@' not in path and 'Cookie' not in headers for path,headers in requests)
print('PASS separate company consent and decoded raster displayed')
settings.set_boolean('remote-contact-pictures',False);pump(.1)
assert avatar.get_custom_image() is None
n=len(requests);pump(.1);assert len(requests)==n
print('PASS withdrawal clears image and stops requests')
close(picture)
for kind in ('svg','redirect','oversized'):
 mode=kind;settings.set_boolean('company-pictures',False);settings.set_boolean('remote-contact-pictures',True)
 picture=controller(kind+'@company.com');pump(.5)
 assert avatar.get_custom_image() is None,kind
 close(picture);print('PASS rejects '+kind)
mode='delayed';picture=controller('delayed@company.com');pump(.1)
settings.set_boolean('remote-contact-pictures',False);pump(.7)
assert avatar.get_custom_image() is None
close(picture);print('PASS cancelled response cannot repopulate picture')
assert set(connections) <= {'www.gravatar.com:443','icons.duckduckgo.com:443'},connections
window.close();server.shutdown();proxy.shutdown()
print('All HTTPS/widget fixtures passed; synthetic TLS trust and DNS only, no external network.')
