---
name: pdf
description: "Use when user says /pdf, wants to generate a branded PDF from Markdown, or asks to create a PDF document with Think Labs branding"
user-invocable: true
argument-hint: "<path-to-markdown | description of document to create>"
---

# PDF Skill

Generate a branded Think Labs PDF from Markdown using the branding repo's PDF builder.

## Prerequisites

This skill requires the branding repo's `pdf:build` script. Locate it:

1. Check if current directory is the branding repo (`package.json` has `@think-labs/branding`)
2. If not, look for it at `~/repos/tl/branding`
3. If not found, tell the user and stop

Store the resolved branding repo path as `BRANDING_ROOT`.

## Step 1: Determine Input

The argument is either:

- **A file path** (ends in `.md`) → use it directly as the content source
- **A description** (anything else) → write the Markdown content to a temp file, then use that as the content source. Use good document structure: headings, sections, tables, lists as appropriate.

## Step 2: Extract Metadata

If the Markdown has YAML front matter, extract:

| Front matter key | Maps to CLI flag |
| ---------------- | ---------------- |
| `title`          | `--title`        |
| `subtitle`       | `--subtitle`     |
| `date`           | `--date`         |
| `cover`          | `--cover`        |

If no front matter, ask the user for a title at minimum.

## Step 3: Select Cover

If front matter doesn't specify a cover:

1. Run `npm run pdf:build --prefix "$BRANDING_ROOT" -- --list-covers` to get available covers
2. If only one cover exists, use it as the default
3. If multiple covers exist, show the options and ask the user which one to use

## Step 4: Determine Output Path

Output defaults to the same directory and basename as the input `.md` file, with a `.pdf` extension.

- `~/docs/report.md` → `~/docs/report.pdf`
- If the input was a description (temp file), ask the user where to save it

## Step 5: Build the PDF

Run the build command from `BRANDING_ROOT`:

```bash
npm run pdf:build --prefix "$BRANDING_ROOT" -- \
  --content "<absolute-path-to-md>" \
  --cover "<cover-name>" \
  --title "<title>" \
  --subtitle "<subtitle>" \
  --date "<date>" \
  --out "<absolute-output-path>"
```

Omit `--subtitle` and `--date` flags if not provided.

## Step 6: Report

Tell the user the output path and file size.

## Rules

- Always use absolute paths for `--content` and `--out`
- Never modify the source Markdown file
- If the build fails, show the error output
