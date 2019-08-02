'use strict';

chrome.runtime.sendMessage({type: "AWS_AD_credentials_fetcher_get_parameter", key: "app"}, function(response) {
    const appName = response.toUpperCase()
    if (!appName) {
        console.warn("No app parameter specified. Select app manually.")
        return
    }
    const clickInternval = setInterval(function () {
        const tiles = document.getElementsByClassName('name')
        for (var i = 0; i < tiles.length; ++i) {
            if (tiles[i].outerText.toUpperCase().includes(appName)) {
                tiles[i].click()
                clearInterval(clickInternval)
                break
            }
        }
    }, 100)
})

