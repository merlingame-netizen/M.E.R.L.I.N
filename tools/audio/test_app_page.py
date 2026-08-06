import asyncio, sys
from playwright.async_api import async_playwright
CHROME="/opt/pw-browsers/chromium-1194/chrome-linux/chrome"

async def main():
    errs=[]
    async with async_playwright() as pw:
        b = await pw.chromium.launch(executable_path=CHROME,
                args=["--autoplay-policy=no-user-gesture-required"])
        # EMULATION MOBILE REELLE : is_mobile+has_touch met pointer:coarse,
        # sans quoi la regle des cibles 44px ne s'applique pas au test.
        ctx = await b.new_context(viewport={"width":390,"height":844},
                is_mobile=True, has_touch=True, device_scale_factor=3,
                user_agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                           "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile Safari/604.1")
        pg = await ctx.new_page()
        pg.on("console", lambda m: errs.append(m.text) if m.type=="error" else None)
        pg.on("pageerror", lambda e: errs.append("PAGEERROR: "+str(e)))
        await pg.goto("file://"+sys.argv[1]); await pg.wait_for_timeout(1500)
        print("  coarse pointer  :", await pg.evaluate("matchMedia('(pointer:coarse)').matches"))
        small=[]
        for sel in (".cand",".chip",".play"):
            for i in range(await pg.locator(sel).count()):
                bb=await pg.locator(sel).nth(i).bounding_box()
                if bb and bb["height"]<44: small.append((sel,i,round(bb["height"])))
        print("  cibles < 44px   :", len(small), small[:4])
        print("  scrollWidth     :", await pg.evaluate("document.documentElement.scrollWidth"),
              "(viewport 390)")
        print("  avertissement   :", (await pg.locator("#msg").text_content() or "")[:60])
        await pg.click("#play"); await pg.wait_for_timeout(6000)
        st=await pg.evaluate("""()=>({eng:document.querySelector('#engine').textContent,
            wg:webGain, t:+el.bed.currentTime.toFixed(2), clock:document.querySelector('#t').textContent,
            g:Object.fromEntries(Object.entries(gain).map(([k,x])=>[k,+x.gain.value.toFixed(3)]).filter(([k,v])=>v>0.001))})""")
        print("  moteur          :", st["eng"], "| webGain =", st["wg"])
        print("  bed.currentTime :", st["t"], "| horloge", st["clock"])
        print("  gains actifs    :", st["g"])
        await pg.click('.cand[data-id="psaltery"]'); await pg.wait_for_timeout(5000)
        g=await pg.evaluate("()=>+gain['corde__psaltery'].gain.value.toFixed(3)")
        old=await pg.evaluate("()=>+gain['corde__celtic_guitar'].gain.value.toFixed(3)")
        print(f"  psalterion      : {g}  (cible 1.927 — impossible sans noeud de gain)")
        print(f"  guitare sortie  : {old}  (cible 0)")
        # etat des elements : un seul titulaire par role doit jouer
        pl=await pg.evaluate("()=>Object.entries(el).filter(([k,a])=>!a.paused).map(([k])=>k)")
        print("  pistes en cours :", sorted(pl))
        await b.close()
    print("  erreurs console :", len(errs), errs[:3])
    ok = not errs and not small and abs(g-1.927)<0.02 and old<0.01
    print("  ==>", "OK" if ok else "A CORRIGER")
    return 0 if ok else 1
sys.exit(asyncio.run(main()))
