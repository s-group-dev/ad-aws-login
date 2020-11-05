'use strict';

// selects the username automatically.
// clicks on the first username once it appears
setInterval(function () {
    const rows = document.getElementsByClassName("table-row")
    if (rows.length > 0) {
        rows[0].click()
    }
}, 100)
