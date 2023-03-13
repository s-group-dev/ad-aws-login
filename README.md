<!-- Analysis -->
![GitHub language count](https://img.shields.io/github/languages/count/s-group-dev/ad-aws-login)
![GitHub top language](https://img.shields.io/github/languages/top/s-group-dev/ad-aws-login)<!-- Size -->
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/s-group-dev/ad-aws-login)
![Lines of code](https://img.shields.io/tokei/lines/github/s-group-dev/ad-aws-login)<!-- Activity -->
![GitHub contributors](https://img.shields.io/github/contributors/s-group-dev/ad-aws-login)

# Azure AD Login to AWS

The `ad-aws-login` script fetches temporary AWS credentials with Azure AD
login (https://myapps.microsoft.com).

So far this has been used **only on OS X** and with **Google Chrome** and **Microsoft Edge**.

The script launches browser with a separate session and helps you
through the login with a dedicated extension. Because this is a new session,
Edge will ask you about default browser etc. And if you choose "Remember me"
on the first login, you don't need to enter your username all the time.

The motivation for all this was to get rid of the host of dependencies
[aws-azure-login](https://github.com/sportradar/aws-azure-login) requires.
Now the codebase is compact enough that you can read it through, and verify
that is not malicious. (apart from minified aws sdk which you can download
yourself from https://github.com/aws/aws-sdk-js/releases)

## How it works

The script adds temporary credentials to `~/.aws/credentials` (or the file
configured by environment variable AWS_SHARED_CREDENTIALS_FILE, if defined).
You can then use those credentials by setting your `AWS_PROFILE` environment
variable accordingly.

Logging in gets you into the role you've been assigned to by default. To
assume other roles, it's recommended you have a section in `~/.aws/config`
(or the file configured by environment variable AWS_CONFIG_FILE, if
defined) for each role you're going to use. Something like this:

```
[profile <profile name for role to assume>]
region=<your region>
source_profile=<the profile name in ~/.aws/credentials you log in to>
role_arn=<arn for the role to assume>
app=A substring of the app name shown in myapps.microsoft.com to launch. Case-insensitive. Must be url encoded.
```

Note: you might have to create the folder and touch the config file before
running this script, if you are configuring AWS to a completely new location.

Add `bin/` to your `$PATH` to get `ad-aws-login` available everywhere.

## Usage

```
Usage: ad-aws-login [OPTIONS]

  Simple script that fetches temporary AWS credentials with Azude AD login
  (https://myapps.microsoft.com).

Options:
  --profile  TEXT    The name of the profile in ~/.aws/credentials to update.
  --app      TEXT    A substring of the app name shown in myapps.microsoft.com
                     to launch. Case-insensitive.
  --duration INTEGER How many hours the temporary credentials are valid.
  --role-arn TEXT    AWS IAM Role to assume with AD credentials.
```

You can also run it without any parameters and it will pick up any settings from your `~/.aws/config` and ask for others.

## Installation

You can run the script from this directory or add `bin` to your path like this:
```
echo "export PATH=\"\${PATH}:$(pwd)/bin\"" >> ~/.zshrc
# OR
echo "export PATH=\"\${PATH}:$(pwd)/bin\"" >> ~/.bashrc
```

... depending of your shell.

By adding this to your path, you can run
```
ad-aws-login  # to run the script
. selaws      # to export AWS_PROFILE and AWS_DEFAULT_REGION to your session
```

## Example

Log in to your sandbox account. Assuming the link to the sandbox account in
myapps.microsoft.com is called "AWS test", then `--app` argument should be
"AWS test". If `--app` or `--role-arn` is missing from parameters, you are asked
to select them in browser. Can be written in the `.aws/config` file aswell. Write temporary credentials to `~/.aws/credentials` 
under a profile called `sandbox`:

```
./ad-aws-login.sh --profile sandbox --app "AWS test" --duration 4 --role-arn arn:aws:iam::123456789012:role/Developer
# Unset any lingering AWS credentials from environment
unset AWS_SESSION_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
# Set active profile to andbox
export AWS_PROFILE=sandbox
```

You can also configure your profile in `.aws/config`. Do note that profiles should be separated with a newline
```
[profile test-admin]
region=eu-west-1
app=AWS test
ad_login_role_arn=arn:aws:iam::123456789012:role/Developer

[profile another-profile]
...
```

**Note** Please rename your role arn name. It is reserved for aws_cli
```
  source_profile => remove source_profile
  role_arn => ad_login_role_arn  
```

**Note** Your account probably has some maximum session duration. Trying to
use longer `--duration` will cause the script to get stuck.

If you don't want script to modify your existing ~/.aws folder, you can
configure your profile / credentials to an alternative location:
```
export AWS_CONFIG_FILE="/somewhere/else/.aws-alt/config"
export AWS_SHARED_CREDENTIALS_FILE="/somewhere/else/.aws-alt/credentials"
mkdir -p /somewhere/else/.aws-alt
# and add your configuration there
```

In order for aws cli to use this alternave .aws home (say, in a new shell),
you must export AWS_CONFIG_FILE and AWS_SHARED_CREDENTIALS_FILE variables.

## Useful commands

If you have [fzf](https://github.com/junegunn/fzf) installed, `ad-aws-login` will use it automatically for better experience.

## Troubleshooting

- [`myapps.microsoft.com`](myapps.microsoft.com) does not render, the screen is blank
   - Delete the `user_data` folder in the root of `ad-aws-login` repository and try again

## More Resouces

- [Contributing](CONTRIBUTING.md)

## [License](./LICENSE)

Conventional Changelog Action is [MIT licensed](./LICENSE).

## Collaboration

If you have questions or [issues](https://github.com/s-group-dev/ad-aws-login/issues), please [open an issue](https://github.com/s-group-dev/ad-aws-login/issues/new)!

## TODO

* Downloading the credentials from chrome as a file is not that neat. Is there
  some other communication channel? What changes to chrome extension would
  enable it to write the file directly? (`~/.aws` is about as safe as
  `~/Downloads` so I think this is a matter of style)
