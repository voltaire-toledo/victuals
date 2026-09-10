# SSH/GitHub comes surprisingly early

This is where I'd create the GitHub SSH key.

You want access to your private configuration before doing much customization.

First:

```
sudo apt install git openssh-client
```

Check whether Ubuntu already created anything:

```
ls -la ~/.ssh
```

For a new laptop, I'd create a new key specifically for this machine, rather than 
copying a private key from another computer:

```
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Use a passphrase.

GitHub currently recommends Ed25519 for ordinary SSH keys and documents adding the 
resulting public key to your account. GitHub Docs

Then:

```
cat ~/.ssh/id_ed25519.pub
```

Add that public key to GitHub's SSH key settings.

**Never upload the `~/.ssh/id_ed25519` file**

Only:

```
~/.ssh/id_ed25519.pub
```
Test it:

```
ssh -T git@github.com
```

You should get GitHub's successful authentication message.
GitHub's official SSH setup instructions
