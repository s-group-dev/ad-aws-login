'use strict';

// if user did not specify role arn from the command line,
// let the user to select the role arn from the AWS list.
(function () {
    if (parameters.roleArn) {
        return
    }

    function inject() {
        const checked = document.querySelectorAll('input[type=radio]:checked');
        if (checked.length !== 1) {
            return;
        }
        const roleArn = checked[0].id;

        chrome.runtime.sendMessage({type: 'AWS_AD_Credentials_set_role', roleArn: roleArn});

    }
    document.getElementById('signin_button').addEventListener('click', function(event) { inject(); event.preventDefaut(); return false; })
}())

