'use strict';

// click on first username once it appears
setInterval(function () {
    const rows = document.getElementsByClassName("table-row")
    if (rows.length > 0) {
        rows[0].click()
    }
}, 100)
