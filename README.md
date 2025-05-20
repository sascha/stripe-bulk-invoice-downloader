# Bulk Stripe Invoice Downloader

**bulk-stripe-invoices.sh** is a tiny macOS‑friendly Bash script that mass‑downloads PDF invoices from your Stripe account so you can upload them into bookkeeping or tax software.

---

## Features

* **Date filter** – grab every invoice created **on or after** a date you choose.
* **Status filter** – optionally restrict to `paid`, `open`, etc.
* **Mode selection** – use either live mode (default) or test mode.
* **Pagination** – automatically handles multiple pages of results from the Stripe API.
* **Dry‑run mode** – preview exactly what will be fetched before anything is written.
* **Clean filenames** – each invoice is saved as `<invoice_id>.pdf` in the folder you specify.
* **Works offline** – no direct API calls; everything runs via the official `stripe` CLI.

---

## Requirements

| Tool                  | Install with Homebrew | Notes                                                             |
| --------------------- | --------------------- | ----------------------------------------------------------------- |
| **Stripe CLI** ≥ 1.17 | `brew install stripe` | Make sure you run `stripe login` first *or* set `STRIPE_API_KEY`. |
| **jq**                | `brew install jq`     | Used for fast JSON parsing.                                       |

Tested on macOS 15 (Sequoia) but should work on any POSIX‑compatible shell with minor tweaks.

---

## Installation

```bash
# Clone or download the script
curl -O https://raw.githubusercontent.com/sascha/stripe-bulk-invoice-downloader/bulk-stripe-invoices.sh

# Make it executable
chmod +x bulk-stripe-invoices.sh

# (Optional) Move it somewhere in your $PATH
mv bulk-stripe-invoices.sh /usr/local/bin/
```

---

## Quick start

```bash
# Download every invoice from 2024‑01‑01 onwards into ~/Downloads/invoices
./bulk-stripe-invoices.sh -d 2024-01-01 -o ~/Downloads/invoices
```

Or try a dry run first:

```bash
./bulk-stripe-invoices.sh -d 2024-01-01 -o ~/Downloads/invoices -n
```

---

## Usage & options

```text
Usage: bulk-stripe-invoices.sh -d YYYY-MM-DD -o OUTPUT_DIR [options]

Required:
  -d DATE        Starting date (inclusive) in YYYY-MM-DD format.
  -o DIR         Folder to save PDFs to (created if it doesn't exist).

Options:
  -s SECRET      Stripe secret key (overrides login / STRIPE_API_KEY).
  -l LIMIT       Page size for each API call (default 100, max 100).
  -t STATUS      Invoice status filter (default: all) – e.g. paid, open.
  -n             Dry‑run; list what would be downloaded without saving.
  -T             Use test mode (default: live mode).
  -h             Show help and exit.
```

### Filtering by status

Need only paid invoices? Easy:

```bash
./bulk-stripe-invoices.sh -d 2024-01-01 -o ./paid-invoices -t paid
```

### Using test mode

To download invoices from your test environment:

```bash
./bulk-stripe-invoices.sh -d 2024-01-01 -o ./test-invoices -T
```

### Authenticating with an environment variable

```bash
export STRIPE_API_KEY=sk_live_xxx
./bulk-stripe-invoices.sh -d 2024-01-01 -o ./invoices
```

---

## Contributing

Found a bug or have an idea? Open an issue or PR—bug‑fixes and enhancements welcome!

---

## License

Released under the **MIT License** - see `LICENSE` for details.
© 2025 Sascha Schwabbauer
