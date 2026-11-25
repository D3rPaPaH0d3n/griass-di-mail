"""Synthetic D-Bus consumer. Run under a disposable private session with the test ELF loader."""
import subprocess, sys, time, xml.etree.ElementTree as ET
from gi.repository import Gio, GLib
name='org.example.GriassdiBadgeFixture'; path='/StatusNotifierItem'; iface='org.kde.StatusNotifierItem'
bus=Gio.bus_get_sync(Gio.BusType.SESSION); signals=[]
def call(interface,method,args=None,where=path):
    return bus.call_sync(name,where,interface,method,args,None,Gio.DBusCallFlags.NONE,2000,None).unpack()
def prop(p): return call('org.freedesktop.DBus.Properties','Get',GLib.Variant('(ss)',(iface,p)))[0]
def header(): return call('com.canonical.dbusmenu','GetProperty',GLib.Variant('(is)',(5,'label')),path+'/Menu')[0]
def on_label(conn,sender,path,interface,signal,args,user): signals.append(args.unpack())
bus.signal_subscribe(None,iface,'XAyatanaNewLabel',path,None,Gio.DBusSignalFlags.NONE,on_label,None)
p=subprocess.Popen(sys.argv[1:]+['--badge-fixture'])
try:
    for _ in range(200):
        assert p.poll() is None, 'fixture exited'
        try: xml=call('org.freedesktop.DBus.Introspectable','Introspect')[0]; break
        except GLib.Error: time.sleep(.025)
    else: raise RuntimeError('fixture not available')
    desc=ET.fromstring(xml).find("interface[@name='"+iface+"']")
    for attr in ['XAyatanaLabel','XAyatanaLabelGuide']: assert desc.find("property[@name='"+attr+"']").get('type')=='s'
    assert [a.get('type') for a in desc.find("signal[@name='XAyatanaNewLabel']").findall('arg')]==['s','s']
    ctx=GLib.MainContext.default()
    def drain():
        while ctx.pending(): ctx.iteration(False)
    assert prop('XAyatanaLabel')=='31' and header()=='No new mail'; assert prop('IconName').endswith('-tray')
    print('startup: 23+6+2=31; popup: No new mail; closed envelope')
    drain(); signals.clear(); old='31'
    for step,expected in enumerate(['30','31','37','25','23','23','23','23','','80','90','1002'],1):
        call(iface,'Activate',GLib.Variant('(ii)',(0,0))); actual=prop('XAyatanaLabel'); assert actual==expected,(step,actual,expected)
        assert prop('ToolTip')[3]=='All Inboxes: '+(actual or '0'); assert prop('Title')=='Griaß di Mail'
        assert header()==('No new mail' if step<8 else '1 new message')
        drain(); assert signals==([(expected,'')] if old!=expected else []),(step,signals)
        print('step',step,'label',repr(actual),'XAyatanaNewLabel',signals,'menu',header()); signals.clear(); old=expected
    print('PASS canonical Get, introspection, signals and payloads; no duplicate signals; no 999 cap')
finally:
    p.terminate(); p.wait(timeout=3)
