(function() {
    'use strict';

    let parameters = {
        durationHours: 4,
        filename: "temporary_aws_credentials.txt"
    }

    function saveCredentials(credentials) {
        const data =
`aws_access_key_id=${credentials.AccessKeyId}
aws_secret_access_key=${credentials.SecretAccessKey}
aws_session_token=${credentials.SessionToken}
aws_session_expiration=${credentials.Expiration.toJSON()}
`
        var blob = new Blob([data], {type: "text/plain"});
        var url = URL.createObjectURL(blob);
        chrome.downloads.download({
          url: url,
          filename: parameters.filename
        });
    }

    function readUrlParams(url) {
        let keyValues = url.slice(url.indexOf('?') + 1).split('&')
        keyValues.map(keyValue => {
            let [key, val] = keyValue.split('=')
            parameters[key] = decodeURIComponent(val)
        })
    }

    chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
        if (request.type === 'AWS_AD_credentials_fetcher_get_parameter') {
            sendResponse(parameters[request.key])
        }
        if (request.type === "AWS_AD_credentials_get_role") {
            sendResponse(parameters[request.key])
        }
        if (request.type === 'AWS_AD_Credentials_set_role') {
            parameters.roleArn = request.roleArn;
        }
        return true;
    });

    function onBeforeRequestListener(details) {
        if (details.url.startsWith('http://localhost/')) {
            readUrlParams(details.url)
            return {redirectUrl: 'https://myapps.microsoft.com'}
        }

        // ignore everything except redirect to aws
        if (details.url !== 'https://signin.aws.amazon.com/saml') {
            return
        }

        const SAMLResponse = details.requestBody.formData.SAMLResponse[0]
        var re = null;
        var arn = null;
        if (parameters.roleArn) {
            re = new RegExp("\<Attribute Name\=\"https\:\/\/aws\.amazon\.com\/SAML\/Attributes\/Role\"\>.*\<AttributeValue\>" + parameters.roleArn + ",([^<]+)\<\/AttributeValue\>.*\<\/Attribute\>");
            arn = atob(SAMLResponse).match(re);
        }
        if (!arn) {
            console.error("Could not parse role / principal from SAML");
        }

        const params = {
            SAMLAssertion: SAMLResponse,
            DurationSeconds: parameters.durationHours * 3600,
        };
        if (parameters.roleArn) {
            params.RoleArn = parameters.roleArn;
            params.PrincipalArn = arn[1];
        } else {
            params.RoleArn = arn[1];
            params.PrincipalArn = arn[2];
        }

        const sts = new AWS.STS();
        sts.assumeRoleWithSAML(params, function(err, data) {
            if (err) {
                console.log("sts error", err, err.stack);
            } else {
                saveCredentials(data.Credentials);
            }
        });
        
        // prevent going to aws
        return {redirectUrl: 'javascript:void(0)'}
    }

    chrome.webRequest.onBeforeRequest.addListener(onBeforeRequestListener, {
        urls: ['<all_urls>'],
        types: ['main_frame', 'sub_frame'],
    }, ['blocking', 'requestBody']);

    chrome.contentSettings.popups.set({setting: "allow", primaryPattern: "https://account.activedirectory.windowsazure.com/*"})
})();
