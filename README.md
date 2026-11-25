# Periods

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/periods`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

`periods` is published to the `network-for-good` GitHub Packages registry, not RubyGems.org. In a
consuming app's `Gemfile`:

```ruby
source "https://rubygems.pkg.github.com/network-for-good" do
  gem "periods", "~> 0.2"
end
```

Bundler needs a token with `read:packages` for that source, for example
`BUNDLE_RUBYGEMS__PKG__GITHUB__COM=<user>:<token>` (CI uses the org secret of the same name).

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## CI and Releasing

GitHub Actions runs everything; there is no CircleCI, Travis or Solano config for this repo.

| Workflow | Runs on | Does |
| --- | --- | --- |
| `.github/workflows/test.yml` | every pull request targeting `main` (and called by the publish workflow) | Runs `bundle exec rspec`. Reports the check `test`. |
| `.github/workflows/publish-gem.yml` | every push to `main` | Runs the tests, then publishes the gem to GitHub Packages and tags the release, but only if the version is new. |

These are in-repo copies of the shared gem workflows in the private
[`nfg-devx`](https://github.com/network-for-good/nfg-devx) repository (`docs/gem-workflows.md` there
describes them), taken at `gem-workflows-v1.0.0`. `periods` is a public repository and cannot call
workflows stored in a private one, so the copy is interim until periods becomes internal (planned by
Platform) and can call the shared workflows directly, or a shared public workflows repository
exists. The build job runs with a read-only token; only the small publish job can write packages and
tags. Actions are pinned to full commit SHAs, and Dependabot proposes updates to them, except
`ruby/setup-ruby`, which is bumped by hand because the org Actions allowlist only accepts specific
SHAs (see the comment in `.github/dependabot.yml`).

**What triggers a release.** Versions are not computed from commit messages. To release, bump
`VERSION` in `lib/periods/version.rb` in your pull request. When that PR merges to `main` and the
tests pass, the workflow builds the gem, publishes it, and tags the commit `v<version>`. A merge that
does not change the version finds the `v<version>` tag already present and publishes nothing. Do not
run `rake release`, `gem push` or `git tag` by hand.

If a run publishes the package but fails to push the tag, re-run the workflow: it detects the
published version and recreates the tag only if the published package matches the commit.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/network-for-good/periods. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Periods project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/network-for-good/periods/blob/master/CODE_OF_CONDUCT.md).
