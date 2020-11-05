'use strict';

// if user did not specify role arn from the command line,
// let the user to select the role arn from the AWS list.
chrome.runtime.sendMessage({type: "AWS_AD_credentials_get_role", key: "roleArn"}, function(response) {
    const roleName = response.toUpperCase()
    if (roleName) {
        return
    }

    var inject = function() {
        var checked = document.querySelectorAll('input[type=radio]:checked');
        if (checked.length !== 1) {
            return;
        }
        var role = checked[0].id;

        chrome.runtime.sendMessage({type: 'AWS_AD_Credentials_set_role', roleArn: role});

    }
    document.getElementById('signin_button').addEventListener('click', function(event) { inject(); event.preventDefaut(); return false; })
})

