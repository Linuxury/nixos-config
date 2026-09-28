const MILLENNIUM_IS_CLIENT_MODULE = true;
const pluginName = "protondb-status";
function InitializePlugins() {
    var _a, _b;
    /**
     * This function is called n times depending on n plugin count,
     * Create the plugin list if it wasn't already created
     */
    (_a = (window.PLUGIN_LIST || (window.PLUGIN_LIST = {})))[pluginName] || (_a[pluginName] = {});
    (_b = (window.MILLENNIUM_PLUGIN_SETTINGS_STORE || (window.MILLENNIUM_PLUGIN_SETTINGS_STORE = {})))[pluginName] || (_b[pluginName] = {});
    window.MILLENNIUM_SIDEBAR_NAVIGATION_PANELS || (window.MILLENNIUM_SIDEBAR_NAVIGATION_PANELS = {});
    /**
     * Accepted IPC message types from Millennium backend.
     */
    let IPCType;
    (function (IPCType) {
        IPCType[IPCType["CallServerMethod"] = 0] = "CallServerMethod";
    })(IPCType || (IPCType = {}));
    let MillenniumStore = window.MILLENNIUM_PLUGIN_SETTINGS_STORE[pluginName];
    let IPCMessageId = `Millennium.Internal.IPC.[${pluginName}]`;
    let isClientModule = MILLENNIUM_IS_CLIENT_MODULE;
    const ComponentTypeMap = {
        DropDown: ['string', 'number', 'boolean'],
        NumberTextInput: ['number'],
        StringTextInput: ['string'],
        FloatTextInput: ['number'],
        CheckBox: ['boolean'],
        NumberSlider: ['number'],
        FloatSlider: ['number'],
    };
    MillenniumStore.ignoreProxyFlag = false;
    function DelegateToBackend(pluginName, name, value) {
        return MILLENNIUM_BACKEND_IPC.postMessage(IPCType.CallServerMethod, {
            pluginName,
            methodName: '__builtins__.__update_settings_value__',
            argumentList: { name, value },
        });
    }
    async function ClientInitializeIPC() {
        /** Wait for the MainWindowBrowser to not be undefined */
        while (typeof MainWindowBrowserManager === 'undefined') {
            await new Promise((resolve) => setTimeout(resolve, 0));
        }
        MainWindowBrowserManager?.m_browser?.on('message', (messageId, data) => {
            if (messageId !== IPCMessageId) {
                return;
            }
            const { name, value } = JSON.parse(data);
            MillenniumStore.ignoreProxyFlag = true;
            MillenniumStore.settingsStore[name] = value;
            DelegateToBackend(pluginName, name, value);
            MillenniumStore.ignoreProxyFlag = false;
        });
    }
    if (isClientModule) {
        ClientInitializeIPC();
    }
    const StartSettingPropagation = (name, value) => {
        if (MillenniumStore.ignoreProxyFlag) {
            return;
        }
        if (isClientModule) {
            DelegateToBackend(pluginName, name, value);
            /** If the browser doesn't exist yet, no use sending anything to it. */
            if (typeof MainWindowBrowserManager !== 'undefined') {
                MainWindowBrowserManager?.m_browser?.PostMessage(IPCMessageId, JSON.stringify({ name, value }));
            }
        }
        else {
            /** Send the message to the SharedJSContext */
            SteamClient.BrowserView.PostMessageToParent(IPCMessageId, JSON.stringify({ name, value }));
        }
    };
    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }
    const DefinePluginSetting = (obj) => {
        return new Proxy(obj, {
            set(target, property, value) {
                if (!(property in target)) {
                    throw new TypeError(`Property ${String(property)} does not exist on plugin settings`);
                }
                const settingType = ComponentTypeMap[target[property].type];
                const range = target[property]?.range;
                /** Clamp the value between the given range */
                if (settingType.includes('number') && typeof value === 'number') {
                    if (range) {
                        value = clamp(value, range[0], range[1]);
                    }
                    value || (value = 0); // Fallback to 0 if the value is undefined or null
                }
                /** Check if the value is of the proper type */
                if (!settingType.includes(typeof value)) {
                    throw new TypeError(`Expected ${settingType.join(' or ')}, got ${typeof value}`);
                }
                target[property].value = value;
                StartSettingPropagation(String(property), value);
                return true;
            },
            get(target, property) {
                if (property === '__raw_get_internals__') {
                    return target;
                }
                if (property in target) {
                    return target[property].value;
                }
                return undefined;
            },
        });
    };
    MillenniumStore.DefinePluginSetting = DefinePluginSetting;
    MillenniumStore.settingsStore = DefinePluginSetting({});
}
InitializePlugins()
const __call_server_method__ = (methodName, kwargs) => Millennium.callServerMethod(pluginName, methodName, kwargs)
function __wrapped_callable__(route) {
    if (route.startsWith('webkit:')) {
        return MILLENNIUM_API.callable((methodName, kwargs) => MILLENNIUM_API.__INTERNAL_CALL_WEBKIT_METHOD__(pluginName, methodName, kwargs), route.replace(/^webkit:/, ''));
    }
    return MILLENNIUM_API.callable(__call_server_method__, route);
}
let PluginEntryPointMain = function() { var millennium_main = (function (exports, client) {
    'use strict';

    var UIMode;
    (function (UIMode) {
        UIMode["Desktop"] = "desktop";
        UIMode["BigPicture"] = "bigpicture";
    })(UIMode || (UIMode = {}));
    let patchedAppId = null;
    let patchedMode = null;
    let patchedTitle = null;
    function setRoutePatchData(appId, mode, title) {
        patchedAppId = appId;
        patchedMode = mode;
        patchedTitle = title ?? null;
    }
    function clearRoutePatchData() {
        patchedAppId = null;
        patchedMode = null;
        patchedTitle = null;
    }
    function detectGamePage(_doc, mode) {
        // Only trust patched route data when we're actually being asked about
        // Big Picture — otherwise stale data left over from a previous Big
        // Picture session can hijack desktop detection after switching back.
        if (mode === UIMode.BigPicture &&
            patchedAppId !== null &&
            patchedMode !== null) {
            const title = patchedTitle ?? resolveTitle(patchedAppId) ?? '';
            return { appId: patchedAppId, mode: patchedMode, title };
        }
        const w = window;
        const pathname = w.MainWindowBrowserManager?.m_lastLocation?.pathname;
        if (pathname) {
            const m = pathname.match(/\/app\/(\d+)/);
            if (m) {
                console.log('[ProtonDB] detectGamePage: pathname match', pathname);
                const appId = parseInt(m[1], 10);
                const title = resolveTitle(appId) ?? '';
                return { appId, mode: UIMode.Desktop, title };
            }
        }
        return null;
    }
    function resolveTitle(appId) {
        const w = window;
        const overview = w.appStore?.GetAppOverviewByAppID?.(appId);
        return overview?.display_name ?? overview?.name ?? null;
    }

    const fetchFn = __wrapped_callable__('FetchProtonDb');
    const cache = new Map();
    const NON_STEAM_APPID_THRESHOLD = 0x80000000;
    function isNonSteamGame(appId) {
        return appId >= NON_STEAM_APPID_THRESHOLD;
    }
    async function fetchProtonDbRating(appId, title) {
        if (cache.has(appId)) {
            return cache.get(appId) ?? null;
        }
        try {
            const json = isNonSteamGame(appId)
                ? await fetchFn({ appId: 0, title }) // signal backend to resolve by title
                : await fetchFn({ appId });
            const data = JSON.parse(json);
            if (data.error || !data.tier) {
                cache.set(appId, null);
                return null;
            }
            const rating = {
                tier: data.tier,
                bestReportedTier: data.bestReportedTier ?? data.tier,
                confidence: data.confidence ?? '',
                score: data.score ?? 0,
                total: data.total ?? 0,
                trendingTier: data.trendingTier ?? data.tier,
                appId: data.resolvedAppId
            };
            cache.set(appId, rating);
            return rating;
        }
        catch (e) {
            console.error('[ProtonDB] error fetching rating:', e);
            cache.set(appId, null);
            return null;
        }
    }

    // Live CSS modules resolved at runtime — no hardcoded classnames, so this
    // tracks Steam's actual class hashes even after they change between updates.
    const PlayBar = client.findClassModule?.((m) => !!(m.GameStat && m.PlayBarLabel)) ?? null;
    // GameStatWithIcon is our own label — Steam's real property name for that
    // classname is "Playtime" (per PluginDatabase#158 review). Multiple unrelated
    // modules can define a generic "Playtime" key, so require GameStat too to
    // land on the stats-row module instead of some unrelated module.
    const PlaytimeModule = client.findClassModule?.((m) => !!(m.Playtime && m.GameStat)) ?? null;
    function c(key) {
        if (key === 'GameStatWithIcon') {
            return PlaytimeModule?.Playtime ?? PlayBar?.Playtime ?? '';
        }
        return PlayBar?.[key] ?? '';
    }
    const TIER_COLORS = {
        platinum: '#00b4d8',
        gold: '#FFD700',
        silver: '#C0C0C0',
        bronze: '#CD7F32',
        borked: '#e74c3c'
    };
    function tierLabel(tier) {
        return tier.charAt(0).toUpperCase() + tier.slice(1);
    }
    function tierColor(tier) {
        return TIER_COLORS[tier.toLowerCase()] ?? '#606060';
    }
    let lastOpenMs = 0;
    function openProtonDbPage(appId) {
        const url = 'https://www.protondb.com/app/' + appId;
        const w = window;
        const now = Date.now();
        if (now - lastOpenMs < 800)
            return;
        lastOpenMs = now;
        const openInSystemBrowser = w.SteamClient?.System?.OpenInSystemBrowser;
        if (typeof openInSystemBrowser === 'function') {
            try {
                openInSystemBrowser(url);
                return;
            }
            catch { }
        }
        // Fallback: programmatic external tab open without navigating current Steam webview.
        try {
            const link = w.document.createElement('a');
            link.href = url;
            link.target = '_blank';
            link.rel = 'noopener noreferrer';
            link.style.display = 'none';
            w.document.body.appendChild(link);
            link.click();
            link.remove();
        }
        catch {
            console.warn('[ProtonDB] Could not open ProtonDB URL');
        }
    }
    function _findInDoc(doc) {
        // Use runtime class module — most reliable
        if (PlayBar?.GameStatsSection) {
            const els = doc.querySelectorAll('.' + PlayBar.GameStatsSection);
            if (els.length > 0) {
                const el = els[els.length - 1];
                return el;
            }
        }
        // Fallback: walk up from the PlaytimeIcon element
        if (PlayBar?.PlaytimeIcon) {
            const icons = doc.querySelectorAll('.' + PlayBar.PlaytimeIcon);
            if (icons.length > 0) {
                const icon = icons[icons.length - 1];
                const row = PlayBar.GameStatsSection
                    ? icon.closest('.' + PlayBar.GameStatsSection)
                    : icon.parentElement?.parentElement
                        ?.parentElement;
                if (row)
                    return row;
            }
        }
        // Last resort: literal .SVGIcon_PlayTime (Steam stable class)
        const svgs = doc.querySelectorAll('[class*="SVGIcon_PlayTime"], .SVGIcon_PlayTime');
        if (svgs.length > 0) {
            const row = svgs[svgs.length - 1].parentElement?.parentElement?.parentElement;
            if (row)
                return row;
        }
        return null;
    }
    /**
     * Searches the main document AND all g_PopupManager windows for the game stats toolbar row.
     */
    function findToolbarRow(doc) {
        const inMain = _findInDoc(doc);
        if (inMain) {
            console.log('[ProtonDB] findToolbarRow: found in main document');
            return { row: inMain, doc: doc };
        }
        // Steam renders the game library detail panel in a separate popup window,
        // scoped to g_PopupManager on the SAME window as doc — not the global
        // `window`, which is bound to whichever window this script first ran in.
        const win = doc.defaultView;
        const g_PM = win?.g_PopupManager;
        const popups = g_PM?.GetPopups?.() ?? [];
        let checked = 0;
        for (const popup of popups) {
            let popDoc = null;
            try {
                popDoc = popup?.window?.document;
            }
            catch {
                continue;
            }
            if (!popDoc || popDoc === doc)
                continue;
            checked++;
            const found = _findInDoc(popDoc);
            if (found) {
                console.log('[ProtonDB] findToolbarRow: found in popup', popup?.m_strName ?? popup?.m_strTitle ?? '?');
                return { row: found, doc: popDoc };
            }
        }
        console.log('[ProtonDB] findToolbarRow: NOT FOUND | PlayBar.GameStatsSection:', PlayBar?.GameStatsSection, '| popups checked:', checked, '| total popups:', popups.length);
        return null;
    }
    function createBadge(rating, doc) {
        const tier = rating.tier;
        const color = tierColor(tier);
        const label = tierLabel(tier);
        const tile = doc.createElement('div');
        tile.id = 'protondb-status-badge';
        tile.className = [c('GameStat'), c('GameStatWithIcon')]
            .filter(Boolean)
            .join(' ');
        // Propagate tier colour via currentColor so SVG icon inherits it
        tile.style.color = color;
        tile.style.cursor = 'pointer';
        tile.style.pointerEvents = 'auto';
        tile.title = 'Open ProtonDB page';
        tile.setAttribute('role', 'button');
        tile.setAttribute('tabindex', '0');
        tile.addEventListener('click', (ev) => {
            ev.preventDefault();
            ev.stopPropagation();
            openProtonDbPage(rating.appId);
        });
        tile.addEventListener('mousedown', (ev) => {
            ev.preventDefault();
            ev.stopPropagation();
        });
        tile.addEventListener('keydown', (ev) => {
            if (ev.key === 'Enter' || ev.key === ' ') {
                ev.preventDefault();
                openProtonDbPage(rating.appId);
            }
        });
        // Icon div
        const iconDiv = doc.createElement('div');
        iconDiv.className = [c('GameStatIcon'), c('GameStatIconVariant')]
            .filter(Boolean)
            .join(' ');
        // ProtonDB icon from homarr-labs/dashboard-icons, recolored to Steam muted gray
        const svg = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 491 491');
        svg.setAttribute('width', '23');
        svg.setAttribute('height', '23');
        svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
        const orbits = doc.createElementNS('http://www.w3.org/2000/svg', 'path');
        orbits.setAttribute('fill', 'currentColor');
        orbits.setAttribute('d', 'M470.5,245.5c0-29.8-37.3-58.1-94.6-75.6c13.2-58.3,7.3-104.7-18.5-119.6c-6-3.5-12.9-5.1-20.5-5.1v20.5c4.2,0,7.6,0.8,10.5,2.4c12.5,7.2,17.9,34.4,13.7,69.4c-1,8.6-2.7,17.7-4.7,27c-18-4.4-37.6-7.8-58.2-10c-12.4-17-25.2-32.4-38.2-45.9c29.9-27.8,58-43,77-43V45.1l0,0c-25.2,0-58.2,18-91.6,49.2c-33.4-31-66.4-48.8-91.6-48.8v20.5c19,0,47.1,15.1,77,42.7c-12.8,13.5-25.7,28.8-37.9,45.8c-20.7,2.2-40.4,5.6-58.3,10.1c-2.1-9.2-3.7-18.1-4.8-26.6c-4.3-35,1-62.3,13.4-69.5c2.8-1.7,6.3-2.4,10.5-2.4V45.6l0,0c-7.7,0-14.7,1.7-20.7,5.1c-25.8,14.9-31.6,61.2-18.3,119.3c-57.1,17.6-94.2,45.8-94.2,75.5c0,29.8,37.3,58.1,94.6,75.6c-13.2,58.3-7.3,104.7,18.5,119.6c6,3.5,12.9,5.1,20.6,5.1c25.2,0,58.2-18,91.6-49.2c33.4,31,66.4,48.8,91.6,48.8c7.7,0,14.7-1.7,20.7-5.1c25.8-14.9,31.6-61.2,18.3-119.3C433.4,303.5,470.5,275.3,470.5,245.5z M351.1,184.4c-3.4,11.8-7.6,24-12.4,36.2c-3.8-7.3-7.7-14.7-12-22c-4.2-7.3-8.7-14.5-13.2-21.5C326.5,179,339.1,181.4,351.1,184.4z M309.1,282.1c-7.2,12.4-14.5,24.1-22.1,35c-13.7,1.2-27.5,1.8-41.5,1.8c-13.9,0-27.7-0.6-41.3-1.7c-7.6-10.9-15-22.6-22.2-34.9c-7-12-13.3-24.2-19.1-36.5c5.7-12.3,12.1-24.6,19-36.6c7.2-12.4,14.5-24.1,22.1-35c13.7-1.2,27.5-1.8,41.5-1.8c13.9,0,27.7,0.6,41.3,1.7c7.6,10.9,15,22.6,22.2,34.9c7,12,13.3,24.2,19.1,36.5C322.3,257.7,315.9,270,309.1,282.1z M338.7,270.1c5,12.3,9.2,24.6,12.7,36.5c-12,2.9-24.7,5.4-37.8,7.3c4.5-7.1,9-14.3,13.2-21.7C331,284.9,334.9,277.5,338.7,270.1z M245.7,368c-8.5-8.8-17.1-18.6-25.5-29.4c8.3,0.4,16.7,0.6,25.2,0.6c8.6,0,17.2-0.2,25.5-0.6C262.7,349.4,254.1,359.2,245.7,368z M177.4,314c-13-1.9-25.6-4.3-37.6-7.2c3.4-11.8,7.6-24,12.4-36.2c3.8,7.3,7.7,14.7,12,22C168.5,299.8,172.9,307,177.4,314z M245.2,123.1c8.5,8.8,17.1,18.6,25.5,29.4c-8.3-0.4-16.7-0.6-25.2-0.6c-8.6,0-17.2,0.2-25.5,0.6C228.3,141.7,236.8,131.9,245.2,123.1z M177.3,177.1c-4.5,7.1-9,14.3-13.2,21.7c-4.2,7.3-8.2,14.7-11.9,22c-5-12.3-9.2-24.6-12.7-36.5C151.6,181.5,164.2,179,177.3,177.1z M94.3,292c-32.5-13.9-53.5-32-53.5-46.4c0-14.4,21-32.7,53.5-46.4c7.9-3.4,16.5-6.4,25.4-9.3c5.2,18,12.1,36.7,20.6,55.9c-8.4,19.1-15.2,37.7-20.4,55.6C110.9,298.5,102.3,295.4,94.3,292z M143.7,423c-12.5-7.2-17.9-34.4-13.7-69.4c1-8.6,2.7-17.7,4.7-27c18,4.4,37.6,7.8,58.2,10c12.4,17,25.2,32.4,38.2,45.9c-29.9,27.8-58,43-77,43C149.9,425.4,146.4,424.6,143.7,423z M361.3,353.1c4.3,35-1,62.3-13.4,69.5c-2.8,1.7-6.3,2.4-10.5,2.4c-19,0-47.1-15.1-77-42.7c12.8-13.5,25.7-28.8,37.9-45.8c20.7-2.2,40.4-5.6,58.3-10.1C358.6,335.7,360.2,344.6,361.3,353.1z M396.6,292c-7.9,3.4-16.5,6.4-25.4,9.3c-5.2-18-12.1-36.7-20.6-55.9c8.4-19.1,15.2-37.7,20.4-55.6c9.1,2.8,17.7,6,25.8,9.4c32.5,13.9,53.5,32,53.5,46.4C450,259.9,429,278.2,396.6,292z');
        svg.appendChild(orbits);
        const center = doc.createElementNS('http://www.w3.org/2000/svg', 'circle');
        center.setAttribute('fill', 'currentColor');
        center.setAttribute('cx', '245.4');
        center.setAttribute('cy', '245.5');
        center.setAttribute('r', '41.9');
        svg.appendChild(center);
        iconDiv.appendChild(svg);
        // Text div
        const rightDiv = doc.createElement('div');
        rightDiv.className = c('GameStatRight');
        const labelSpan = doc.createElement('span');
        labelSpan.className = c('PlayBarLabel');
        labelSpan.textContent = 'PROTONDB';
        const valueSpan = doc.createElement('span');
        valueSpan.className = c('PlayBarDetailLabel');
        valueSpan.textContent = label;
        valueSpan.style.color = color;
        rightDiv.appendChild(labelSpan);
        rightDiv.appendChild(valueSpan);
        tile.appendChild(iconDiv);
        tile.appendChild(rightDiv);
        return tile;
    }

    const BADGE_ID = 'protondb-status-badge';
    // Keyed by Steam's window name (e.g. "SP Desktop_uid0") rather than Document
    // identity — Steam can hand out a new Document for the same logical window
    // (e.g. desktop, when returning from Big Picture), and keying by name lets
    // us detect and cleanly replace a stale observer instead of accumulating
    // duplicates that fight over the same DOM.
    const windowStates = new Map();
    function setupRoutePatch(state) {
        const routerHook = window.__ROUTER_HOOK_INSTANCE;
        if (!routerHook) {
            console.log('[ProtonDB] Router hook not available for this window');
            return;
        }
        const patchFn = (props) => {
            const renderFunc = props.children?.props?.renderFunc;
            if (renderFunc) {
                const orig = renderFunc;
                props.children.props.renderFunc = (...args) => {
                    const ret = orig(...args);
                    const overview = ret?.props?.children?.props?.overview;
                    if (overview?.appid) {
                        setRoutePatchData(overview.appid, UIMode.BigPicture, overview.display_name);
                    }
                    return ret;
                };
            }
            return props;
        };
        const EUIMODE_GAMEPAD = 4;
        routerHook.addPatch('/library/app/:appid', patchFn, EUIMODE_GAMEPAD);
        state.routePatchCleanup = () => routerHook.removePatch('/library/app/:appid', patchFn, EUIMODE_GAMEPAD);
    }
    async function handleGamePage(state) {
        try {
            await _handleGamePage(state);
        }
        catch (e) {
            console.error('[ProtonDB] handleGamePage threw:', e);
        }
    }
    function scheduleHandleGamePage(state) {
        if (state.debounceHandle)
            clearTimeout(state.debounceHandle);
        state.debounceHandle = setTimeout(() => {
            state.debounceHandle = null;
            handleGamePage(state);
        }, 100);
    }
    async function _handleGamePage(state) {
        const { doc, mode } = state;
        const info = detectGamePage(doc, mode);
        const detectedAppId = info?.appId ?? null;
        if (detectedAppId !== state.lastLoggedAppId) {
            state.lastLoggedAppId = detectedAppId;
            console.log('[ProtonDB]', mode, 'detection changed → appId:', detectedAppId);
        }
        if (!info) {
            if (state.currentAppId !== null) {
                state.panelDoc?.getElementById(BADGE_ID)?.remove();
                state.panelDoc = null;
                state.currentAppId = null;
                state.processingAppId = null;
            }
            if (mode === UIMode.BigPicture) {
                clearRoutePatchData();
            }
            return;
        }
        const { appId, title } = info;
        if (state.currentAppId !== appId) {
            state.panelDoc?.getElementById(BADGE_ID)?.remove();
            state.currentAppId = appId;
            state.processingAppId = null;
        }
        const existingBadge = state.panelDoc?.getElementById(BADGE_ID);
        if (existingBadge) {
            if (existingBadge.textContent?.includes('Pending')) {
                existingBadge.remove();
                return;
            }
            if (existingBadge.parentElement &&
                existingBadge !== existingBadge.parentElement.lastElementChild) {
                existingBadge.parentElement.appendChild(existingBadge);
            }
            return;
        }
        if (state.processingAppId === appId)
            return;
        state.processingAppId = appId;
        const target = findToolbarRow(state.doc);
        if (!target) {
            state.processingAppId = null;
            return;
        }
        state.panelDoc = target.doc;
        const rating = await fetchProtonDbRating(appId, isNonSteamGame(appId) ? title : undefined);
        if (state.currentAppId !== appId) {
            state.processingAppId = null;
            return;
        }
        if (!rating) {
            state.processingAppId = null;
            return;
        }
        const ACHIEVEMENTS_WAIT_MS = 400;
        const deadline = Date.now() + ACHIEVEMENTS_WAIT_MS;
        while (Date.now() < deadline) {
            const rowNow = target.doc.getElementById(target.row.id) ?? target.row;
            const hasAchievements = Array.from(rowNow.children).some(el => el.textContent?.includes('Achievements'));
            if (hasAchievements)
                break;
            await new Promise(r => setTimeout(r, 50));
        }
        if (state.currentAppId !== appId) {
            state.processingAppId = null;
            return;
        }
        const freshTarget = findToolbarRow(state.doc) ?? target;
        if (freshTarget.doc.getElementById(BADGE_ID)) {
            state.processingAppId = null;
            return;
        }
        state.panelDoc = freshTarget.doc;
        freshTarget.row.appendChild(createBadge(rating, freshTarget.doc));
        state.processingAppId = null;
    }
    function teardownState(state) {
        state.observer?.disconnect();
        if (state.intervalId)
            clearInterval(state.intervalId);
        if (state.debounceHandle)
            clearTimeout(state.debounceHandle);
        state.routePatchCleanup?.();
        state.panelDoc?.getElementById(BADGE_ID)?.remove();
    }
    // Sets up (or re-attaches) an observer for the given named window.
    // - Same name + same doc: already watching this exact window, no-op.
    // - Same name + different doc: Steam handed us a new Document for a window
    //   we already know about (e.g. desktop after returning from Big Picture) —
    //   tear down the stale observer and attach a fresh one to the new doc.
    // - New name: brand new window, set up from scratch.
    function setupObserver(name, doc, mode) {
        const existing = windowStates.get(name);
        if (existing && existing.doc === doc) {
            console.log('[ProtonDB] Observer already running for', name, '— skipping');
            return;
        }
        if (existing) {
            console.log('[ProtonDB] Document changed for', name, '— tearing down stale observer and reattaching');
            teardownState(existing);
        }
        const state = {
            doc,
            mode,
            observer: null,
            intervalId: null,
            debounceHandle: null,
            routePatchCleanup: null,
            currentAppId: null,
            processingAppId: null,
            panelDoc: null,
            lastLoggedAppId: undefined
        };
        if (mode === UIMode.BigPicture) {
            setupRoutePatch(state);
        }
        state.observer = new MutationObserver(() => scheduleHandleGamePage(state));
        state.observer.observe(doc.body, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class']
        });
        state.intervalId = setInterval(() => scheduleHandleGamePage(state), 500);
        windowStates.set(name, state);
        handleGamePage(state);
        console.log('[ProtonDB] Observer set up for', name, '(' + mode + ')', '| total tracked windows:', windowStates.size, '| names:', [...windowStates.keys()]);
    }
    function disconnectObserverForName(name) {
        const state = windowStates.get(name);
        if (!state)
            return;
        teardownState(state);
        windowStates.delete(name);
    }
    function disconnectAllObservers() {
        for (const name of windowStates.keys()) {
            disconnectObserverForName(name);
        }
    }

    var index = client.definePlugin(() => {
        console.log('[ProtonDB] plugin loading...');
        client.Millennium.AddWindowCreateHook?.((context) => {
            if (!context.m_strName?.startsWith('SP '))
                return;
            const doc = context.m_popup?.document;
            if (!doc?.body)
                return;
            const mode = context.m_strName.includes('BPM')
                ? UIMode.BigPicture
                : UIMode.Desktop;
            setupObserver(context.m_strName, doc, mode);
        });
        return {
            title: 'ProtonDB Status',
            icon: null,
            onDismount() {
                disconnectAllObservers();
            },
            content: (window.SP_REACT.createElement(client.Field, { label: 'Show ProtonDB Status' },
                window.SP_REACT.createElement(client.Toggle, { value: localStorage.getItem('protondb-status.show') !== 'false', onChange: (value) => {
                        localStorage.setItem('protondb-status.show', String(value));
                    } })))
        };
    });

    exports.default = index;

    Object.defineProperty(exports, '__esModule', { value: true });

    return exports;

})({}, window.MILLENNIUM_API);
 return millennium_main; };
function ExecutePluginModule() {
    let MillenniumStore = window.MILLENNIUM_PLUGIN_SETTINGS_STORE[pluginName];
    function OnPluginConfigChange(key, __, value) {
        if (key in MillenniumStore.settingsStore) {
            MillenniumStore.ignoreProxyFlag = true;
            MillenniumStore.settingsStore[key] = value;
            MillenniumStore.ignoreProxyFlag = false;
        }
    }
    /** Expose the OnPluginConfigChange so it can be called externally */
    MillenniumStore.OnPluginConfigChange = OnPluginConfigChange;
    MILLENNIUM_BACKEND_IPC.postMessage(0, { pluginName: pluginName, methodName: '__builtins__.__millennium_plugin_settings_parser__' }).then(async (response) => {
        /**
         * __millennium_plugin_settings_parser__ will return false if the plugin has no settings.
         * If the plugin has settings, it will return a base64 encoded string.
         * The string is then decoded and parsed into an object.
         */
        if (typeof response.returnValue === 'string') {
            MillenniumStore.ignoreProxyFlag = true;
            /** Initialize the settings store from the settings returned from the backend. */
            MillenniumStore.settingsStore = MillenniumStore.DefinePluginSetting(Object.fromEntries(JSON.parse(atob(response.returnValue)).map((item) => [item.functionName, item])));
            MillenniumStore.ignoreProxyFlag = false;
        }
        /** @ts-ignore: call the plugin main after the settings have been parsed. This prevent plugin settings from being undefined at top level. */
        let PluginModule = PluginEntryPointMain();
        /** Assign the plugin on plugin list. */
        Object.assign(window.PLUGIN_LIST[pluginName], {
            ...PluginModule,
            __millennium_internal_plugin_name_do_not_use_or_change__: pluginName,
        });
        /** Run the rolled up plugins default exported function */
        let pluginProps = await PluginModule.default();
        function isValidSidebarNavComponent(obj) {
            return obj && obj.title !== undefined && obj.icon !== undefined && obj.content !== undefined;
        }
        if (pluginProps && isValidSidebarNavComponent(pluginProps)) {
            window.MILLENNIUM_SIDEBAR_NAVIGATION_PANELS[pluginName] = pluginProps;
        }
        else {
            console.warn(`Plugin ${pluginName} does not contain proper SidebarNavigation props and therefor can't be mounted by Millennium. Please ensure it has a title, icon, and content.`);
            return;
        }
        /** If the current module is a client module, post message id=1 which calls the front_end_loaded method on the backend. */
        if (MILLENNIUM_IS_CLIENT_MODULE) {
            MILLENNIUM_BACKEND_IPC.postMessage(1, { pluginName: pluginName });
        }
    });
}
ExecutePluginModule()