'use strict';

// clicks the correct aws link in the myapplications.microsoft.com
(function () {
    if (!parameters.appName) {
        console.warn("No app parameter specified. Select app manually.")
        return
    }

    // earlier appName was url encoded,
    // decode it for compatibility with old alias people may have.
    const appNameUpper = decodeURI(parameters.appName).toUpperCase()
    const clickInterval = setInterval(function () {
        for (const tile of document.getElementsByClassName('ms-List-cell')) {
            for (const link of tile.getElementsByTagName('a')) {
                for (const node of Array.from(link.childNodes)) {
                    if (node.innerText.toUpperCase().includes(appNameUpper)) {
                        link.click()
                        clearInterval(clickInterval)
                        return
                    }
                }
            }
        }
    }, 100)
}())

