# Preprocess Markdown
A simple ruby script for preprocessing markdown files

## Usage

```sh
ruby preprocess-markdown.rb -o processed-output.md unprocessed-input.md
```

## Supported Directives

```
\{% define VARIABLE_NAME VALUE %}
```

Declare `VARIABLE_NAME` and assign it a (text) value of `VALUE`

```
\{% VARIABLE_NAME %}
```

Substitute the value of `VARIABLE_NAME` at this location in the text

```
\{% include PATH %}
```

Include the text content of `PATH` at this location in text. Paths are resolved relative to the input file. **The included file is not processed by the preprocessor (sorry)**

## Example

```markdown
{% include example-file.md %}
```
