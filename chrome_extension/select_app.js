'use strict';

// clicks the correct aws link in the myapplications.microsoft.com
chrome.runtime.sendMessage({ type: "AWS_AD_credentials_fetcher_get_parameter", key: "app" }, function (response) {
    const appName = response.toUpperCase()
    if (!appName) {
        console.warn("No app parameter specified. Select app manually.")
        return
    }
    const clickInternval = setInterval(function () {
        const tiles = document.getElementsByClassName('ms-List-cell')
        for (var i = 0; i < tiles.length; ++i) {
            const links = tiles[i].getElementsByTagName('a');
            for (var j = 0; j < links.length; j++) {
                const clickableLink = links[j]
                for (var c = 0; c < links[j].childNodes.length; c++) {
                    const b = links[j].childNodes[c]
                    if (b.innerText.toUpperCase().includes(appName)) {
                        clickableLink.click()
                        clearInterval(clickInternval)
                        break
                    }
                }

            }

        }
    }, 100)
})

