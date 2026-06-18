#!/usr/bin/env python3
"""
PWA Patcher for AXIS School System
- Creates PWA icons (192x192, 512x512) in axis_saas/static/pwa/
- Modifies base.html to show sidebar install button always + fallback modal
- Removes floating install button
"""

import os
import re
import sys
from pathlib import Path

# Try to import PIL for icon generation
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("❌ Pillow not installed. Please install: pip install Pillow")
    sys.exit(1)

# ---------- CONFIG ----------
BASE_HTML = "templates/tenant/base.html"
STATIC_DIR = "axis_saas/static/pwa"
ICONS = {
    "icon-192x192.png": (192, 192),
    "icon-512x512.png": (512, 512),
}


def create_icon(filename, size):
    """Generate a simple icon with text 'AXIS'."""
    img = Image.new("RGB", size, color="#3b82f6")
    draw = ImageDraw.Draw(img)
    # Try to load a font, fallback to default
    try:
        font = ImageFont.truetype("arial.ttf", size // 4)
    except:
        font = ImageFont.load_default()
    text = "AXIS"
    # Get text bbox
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pos = ((size[0] - tw) // 2, (size[1] - th) // 2)
    draw.text(pos, text, fill="white", font=font)
    img.save(filename)
    print(f"✅ Created {filename}")


def generate_icons():
    """Create all icons if they don't exist."""
    os.makedirs(STATIC_DIR, exist_ok=True)
    for name, size in ICONS.items():
        path = os.path.join(STATIC_DIR, name)
        if not os.path.exists(path):
            create_icon(path, size)
        else:
            print(f"⏩ Icon already exists: {path}")


def patch_base_html():
    """Modify base.html: remove floating button, show sidebar button, add fallback modal."""
    if not os.path.exists(BASE_HTML):
        print(f"❌ {BASE_HTML} not found!")
        return

    with open(BASE_HTML, "r") as f:
        content = f.read()

    # ----- 1. Remove floating install container -----
    # Find and remove the floating container completely
    floating_pattern = r'<div id="pwaInstallContainer".*?</div>'
    content = re.sub(floating_pattern, "", content, flags=re.DOTALL)
    print("✅ Removed floating install button")

    # ----- 2. Make sidebar install button always visible -----
    # Replace style="display: none;" with style="display: flex;" (or remove inline style)
    sidebar_btn_pattern = r'(<button id="installAppSidebarBtn".*?)style="display: none;"(.*?>)'
    # If not found, try to add style if missing
    if re.search(sidebar_btn_pattern, content):
        content = re.sub(sidebar_btn_pattern, r'\1style="display: flex;"\2', content)
        print("✅ Sidebar button set to visible")
    else:
        # If style not present, add it
        sidebar_btn = '<button id="installAppSidebarBtn" class="nav-item" style="display: flex; width: 100%; background: none; border: none; text-align: left; cursor: pointer;">'
        content = re.sub(r'<button id="installAppSidebarBtn".*?>', sidebar_btn, content)
        print("✅ Sidebar button style added")

    # ----- 3. Add fallback modal HTML (right before the floating container's old position or at end of body) -----
    fallback_modal = '''
<!-- Fallback Install Modal (shown if native prompt not available) -->
<div id="installFallbackModal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center;">
    <div style="background: var(--surface); border-radius: 1rem; padding: 1.5rem; max-width: 400px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.3);">
        <h3 style="margin-top:0;">Install App</h3>
        <p>To install this app on your device:</p>
        <ul style="padding-left:1.5rem; margin:0.5rem 0;">
            <li><strong>Chrome / Edge:</strong> Click the <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 4v12m-4-4l4 4 4-4"/></svg> icon in the address bar.</li>
            <li><strong>Firefox:</strong> Tap the menu (☰) → "Add to Home screen".</li>
            <li><strong>Safari (iOS):</strong> Tap the share button → "Add to Home Screen".</li>
        </ul>
        <button id="closeFallbackModal" style="background: var(--primary); color: white; border: none; border-radius: 2rem; padding: 0.5rem 1.2rem; font-weight: 600; cursor: pointer; margin-top: 0.5rem;">Got it</button>
    </div>
</div>
<script>
    document.getElementById('closeFallbackModal')?.addEventListener('click', function() {
        document.getElementById('installFallbackModal').style.display = 'none';
    });
    // Close on overlay click
    document.getElementById('installFallbackModal')?.addEventListener('click', function(e) {
        if (e.target === this) this.style.display = 'none';
    });
</script>
'''
    # Insert before </body> or at the end
    if '</body>' in content:
        content = content.replace('</body>', fallback_modal + '\n</body>')
        print("✅ Fallback modal added")
    else:
        # fallback: append to end
        content += fallback_modal
        print("✅ Fallback modal appended (no </body> found)")

    # ----- 4. Update JavaScript to handle fallback -----
    # Find the install button click handler and modify
    # We'll add a check: if deferredPrompt exists, use it; else show fallback modal.
    # We'll also ensure the sidebar button click event is attached.
    # Since we have existing script, we can replace the sidebar button click handler with improved version.
    # Search for the block that attaches click listener to installAppSidebarBtn and replace with new code.
    old_sidebar_handler = r'''const sidebarInstallBtn = document\.getElementById\('installAppSidebarBtn'\);\s*if \(sidebarInstallBtn\) \{\s*sidebarInstallBtn\.addEventListener\('click', async \(\) => \{.*?\}\s*\}\);'''
    new_sidebar_handler = '''
        const sidebarInstallBtn = document.getElementById('installAppSidebarBtn');
        if (sidebarInstallBtn) {
            sidebarInstallBtn.addEventListener('click', async () => {
                if (deferredPrompt) {
                    deferredPrompt.prompt();
                    const result = await deferredPrompt.userChoice;
                    if (result.outcome === 'accepted') {
                        console.log('User accepted the install prompt (sidebar)');
                        sidebarInstallBtn.style.display = 'none';
                    } else {
                        console.log('User dismissed the install prompt (sidebar)');
                    }
                    deferredPrompt = null;
                } else {
                    // Show fallback modal with instructions
                    document.getElementById('installFallbackModal').style.display = 'flex';
                }
            });
        }
'''
    # Use regex to replace the block (non-greedy)
    content = re.sub(old_sidebar_handler, new_sidebar_handler, content, flags=re.DOTALL)
    if old_sidebar_handler not in content:
        # If pattern not found, just append the new handler after the existing script (but we can also add it unconditionally)
        # Let's just add a new script block that ensures the handler is attached.
        extra_js = '''
<script>
    // Ensure sidebar install button works with fallback
    (function() {
        const sidebarBtn = document.getElementById('installAppSidebarBtn');
        if (sidebarBtn) {
            // Remove any existing listeners to avoid duplicates
            sidebarBtn.replaceWith(sidebarBtn.cloneNode(true));
            const newBtn = document.getElementById('installAppSidebarBtn');
            newBtn.addEventListener('click', async () => {
                if (typeof deferredPrompt !== 'undefined' && deferredPrompt) {
                    deferredPrompt.prompt();
                    const result = await deferredPrompt.userChoice;
                    if (result.outcome === 'accepted') {
                        console.log('Accepted');
                        newBtn.style.display = 'none';
                    }
                    deferredPrompt = null;
                } else {
                    document.getElementById('installFallbackModal').style.display = 'flex';
                }
            });
        }
    })();
</script>
'''
        # Insert before </body>
        content = content.replace('</body>', extra_js + '\n</body>')
        print("✅ Added extra JS to handle fallback")
    else:
        print("✅ Updated sidebar install click handler")

    # ----- 5. Ensure the existing CSS hides the button in standalone mode (already present) -----
    # We already have: @media all and (display-mode: standalone) { #installAppSidebarBtn { display: none !important; } }
    # That's fine.

    # Write back
    with open(BASE_HTML, "w") as f:
        f.write(content)

    print("✅ base.html patched successfully.")


if __name__ == "__main__":
    print("🚀 AXIS PWA Patcher starting...")
    generate_icons()
    patch_base_html()
    print("\n🎯 Done! Now run:")
    print("   python manage.py collectstatic")
    print("   python manage.py runserver")
    print("\nThen visit your site on mobile and laptop – the install button will appear in the sidebar (unless already installed).")
