In your situation, reusing the existing SSH key is reasonable because the 
**key itself is what GitHub has authorized**, not the physical computer it 
originally lived on. If the organization uses SSO and that existing key is 
already authorized, copying the same keypair to your new Ubuntu laptop 
preserves that identity unless an org/enterprise owner has revoked its 
authorization. 

The main tradeoff is security: once the private key exists on two laptops, 
compromise of either laptop compromises that SSH identity. If you ever 
revoke/replace the key, both machines will be affected.

## 1. On the OLD computer, identify the correct key

Start with:

```bash
ls -la ~/.ssh
```

Common key names are:

```text
id_ed25519
id_rsa
github
github_ed25519
```

Do **not** assume which one GitHub uses. Check loaded keys:

```bash
ssh-add -l -E sha256
```

Then explicitly test candidate keys against GitHub. For example:

```bash
ssh -T \
  -o IdentitiesOnly=yes \
  -i ~/.ssh/id_ed25519 \
  git@github.com
```

GitHub recommends `IdentitiesOnly=yes` when you need to ensure you're testing 
a specific key. 

Successful output should identify your GitHub username:

```text
Hi YOUR_USERNAME! You've successfully authenticated...
```

Once you've identified the correct private key, record its fingerprint:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519 -E sha256
```

For example:

```text
256 SHA256:abc123... your@email.com (ED25519)
```

Save that fingerprint somewhere visible. You'll compare it on the new laptop.

---

## 2. Make sure you also have the corresponding public key

Normally you'll have both:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

The first is **private**.

The second is **public**.

Check:

```bash
ls -l ~/.ssh/id_ed25519*
```

If the `.pub` file is missing, don't worry. Reconstruct it from the private 
key:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
```

Then:

```bash
chmod 644 ~/.ssh/id_ed25519.pub
```

This does not create a new identity. It derives the existing public key from 
the existing private key.

---

# 3. Transfer it directly between the two computers

My preferred method is a **direct machine-to-machine transfer on a network you 
trust**, rather than email, Slack, Dropbox, Google Drive, GitHub, etc.

Never put a private SSH key into your dotfiles repository.

On your **new Ubuntu laptop**, first create the SSH directory:

```bash
install -d -m 700 ~/.ssh
```

Now determine the old machine's IP address on the old machine:

```bash
hostname -I
```

Suppose it says:

```text
192.168.1.42
```

and your old username is `me`.

From the **new laptop**, copy the private key:

```bash
scp me@192.168.1.42:~/.ssh/id_ed25519 ~/.ssh/id_ed25519
```

Then copy the public key:

```bash
scp me@192.168.1.42:~/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
```

If SSH server access isn't enabled on the old machine, `scp` won't work until it 
has an SSH server running. In that case, an encrypted USB drive is a perfectly 
good alternative.

I would **not** temporarily upload the private key somewhere just to transfer it.

---

# 4. Immediately fix the permissions

This is important. OpenSSH deliberately refuses to use private keys that are 
accessible by other users.

On the **new Ubuntu laptop**:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

Verify:

```bash
ls -ld ~/.ssh
ls -l ~/.ssh/id_ed25519*
```

You want approximately:

```text
drwx------ ... /home/me/.ssh

-rw------- ... id_ed25519
-rw-r--r-- ... id_ed25519.pub
```

Also ensure **you**, rather than root, own them:

```bash
stat -c '%U:%G %a %n' \
  ~/.ssh \
  ~/.ssh/id_ed25519 \
  ~/.ssh/id_ed25519.pub
```

Something like:

```text
me:me 700 /home/me/.ssh
me:me 600 /home/me/.ssh/id_ed25519
me:me 644 /home/me/.ssh/id_ed25519.pub
```

If somehow they're root-owned:

```bash
sudo chown -R "$USER:$USER" ~/.ssh
```

Do not use `sudo git clone` later. GitHub specifically cautions against using 
elevated privileges with normal Git/SSH operations because root has a different 
SSH environment. 

---

# 5. Verify that the copied key is EXACTLY the same key

This is the step I'd consider mandatory.

On the new laptop:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519 -E sha256
```

Compare that with the fingerprint you recorded from the old computer.

They should be **identical**.

For even stronger confirmation, fingerprint the public half:

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub -E sha256
```

It should also show the same fingerprint.

You can additionally prove the `.pub` file corresponds to your private key:

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 > /tmp/derived.pub
```

Then:

```bash
diff \
  <(awk '{print $1,$2}' ~/.ssh/id_ed25519.pub) \
  <(awk '{print $1,$2}' /tmp/derived.pub)
```

No output means they match.

Then remove the temporary file:

```bash
rm /tmp/derived.pub
```

---

# 6. Configure SSH explicitly for GitHub

If this is your only GitHub key, I'd add:

```bash
nano ~/.ssh/config
```

with:

```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Then:

```bash
chmod 600 ~/.ssh/config
```

`IdentitiesOnly yes` is useful because it prevents your agent from trying a collection 
of unrelated keys before the intended GitHub identity.

If your copied key isn't called `id_ed25519`, just use its real path:

```text
IdentityFile ~/.ssh/github-work
```

This becomes particularly valuable once you have personal/work keys or keys for other 
services.

---

# 7. Load the copied key into ssh-agent

First see whether an agent is already available:

```bash
echo "$SSH_AUTH_SOCK"
```

Then:

```bash
ssh-add ~/.ssh/id_ed25519
```

If your existing key has a passphrase, you'll be asked for it.

Verify:

```bash
ssh-add -l -E sha256
```

Again, that fingerprint should match the fingerprint from the old machine. GitHub itself 
recommends comparing the agent's fingerprint with the key registered to your GitHub 
account when troubleshooting authentication. 

If the old key does **not** currently have a passphrase, this migration is also a good 
opportunity to add one:

```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
```

That changes the local encryption protecting the private-key file. It **does not change 
the underlying SSH public key**, so GitHub and your organizations will continue seeing 
exactly the same identity.

That's particularly useful in your situation.

---

# 8. Test GitHub before cloning anything

Now:

```bash
ssh -T git@github.com
```

The first time, you may see:

```text
The authenticity of host 'github.com (...)' can't be established.
ED25519 key fingerprint is SHA256:...
```

Don't simply type `yes` without checking it.

As of August 29, 2026, GitHub publishes this Ed25519 host fingerprint:

```text
SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
```

That is GitHub's currently documented value. 

If it matches, accept it.

You should then get:

```text
Hi YOUR_USERNAME! You've successfully authenticated, but GitHub does not provide shell access.
```

That's success.

---

# 9. Test the organization repository itself

Authentication to GitHub and authorization to a particular organization are related but distinct.

Now actually test the repository you're concerned about:

```bash
git ls-remote git@github.com:YOUR-ORG/SOME-PRIVATE-REPO.git
```

For example:

```bash
git ls-remote git@github.com:acme/private-project.git
```

If you see commit hashes and refs:

```text
abcd123... HEAD
abcd123... refs/heads/main
```

your old credential still has access.

Then clone your dotfiles:

```bash
mkdir -p ~/src
cd ~/src
git clone git@github.com:YOUR_USERNAME/dotfiles.git
```

And test one of the restricted organization repositories afterward.

---

# 10. Why this should preserve your organization access

This is the key detail in your situation.

Suppose your old computer contains:

```text
Private key A
      │
      └──── produces ────> Public key A
                             │
                             ▼
                           GitHub
                             │
                    "This belongs to USER"
                             │
                             ▼
                 Organization authorization
```

If you create an entirely new SSH key on the laptop:

```text
Private key B → Public key B
```

GitHub considers that a **different credential**.

That may require the new key to be authorized again by your organization.

But copying:

```text
Private key A
```

to another machine means both machines prove possession of the same underlying identity:

```text
OLD LAPTOP                      NEW LAPTOP
     │                               │
Private key A                   Private key A
     │                               │
     └──────────┐       ┌────────────┘
                ▼       ▼
               Public key A
                    │
                    ▼
                  GitHub
                    │
              existing identity
                    │
             existing SSO/auth
```

GitHub says an existing SSO-authorized SSH key stays authorized until one of the defined 
revocation events occurs, such as an owner revoking it or you being removed from the 
organization. 

So **moving/copying the private half to another computer does not inherently create a new 
GitHub credential**.

---

## An even better way to transfer it, if both laptops are available

If the old laptop remains under your control, I'd do the migration in this order:

```text
OLD MACHINE
    │
    ├─ identify exact GitHub key
    │
    ├─ verify GitHub login
    │
    └─ record SHA256 fingerprint
             │
             ▼
      secure direct transfer
             │
             ▼
NEW UBUNTU LAPTOP
    │
    ├─ ~/.ssh mode 700
    ├─ private key mode 600
    ├─ public key mode 644
    │
    ├─ verify SHA256 fingerprint
    │
    ├─ configure IdentityFile
    │
    ├─ ssh-add key
    │
    ├─ ssh -T git@github.com
    │
    ├─ git ls-remote ORG/private-repo
    │
    └─ clone private dotfiles
```

Only after that succeeds would I proceed with the rest of your Ubuntu bootstrap.

### One thing I would **not** copy wholesale

I would **not** blindly copy the entire old:

```text
~/.ssh/
```

directory.

Copy the specific private/public key pair you need, and selectively migrate `config` if useful.

In particular, I'd let the new laptop establish its own:

```text
~/.ssh/known_hosts
```

because `known_hosts` isn't part of your identity. It's your machine's record of remote 
server identities. Starting it clean and verifying GitHub's published host fingerprint 
gives you a cleaner trust chain.

So at this point your new-laptop sequence changes slightly: 
**update Ubuntu → verify basic hardware → securely migrate the known GitHub SSH key 
→ verify fingerprint and org access → clone dotfiles → continue the bootstrap.**
