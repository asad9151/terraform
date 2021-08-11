A utility to generate documentation from Terraform modules in various output formats

Usage:
  terraform-docs [PATH] [flags]
  terraform-docs [command]

Available Commands:
  asciidoc    Generate AsciiDoc of inputs and outputs
  completion  Generate shell completion code for the specified shell (bash or zsh)
  help        Help about any command
  json        Generate JSON of inputs and outputs
  markdown    Generate Markdown of inputs and outputs
  pretty      Generate colorized pretty of inputs and outputs
  tfvars      Generate terraform.tfvars of inputs
  toml        Generate TOML of inputs and outputs
  version     Print the version number of terraform-docs
  xml         Generate XML of inputs and outputs
  yaml        Generate YAML of inputs and outputs

Flags:
  -c, --config string               config file name (default ".terraform-docs.yml")
      --header-from string          relative path of a file to read header from (default "main.tf")
  -h, --help                        help for terraform-docs
      --hide strings                hide section [header, inputs, outputs, providers, requirements]
      --hide-all                    hide all sections (default false)
      --output-values               inject output values into outputs (default false)
      --output-values-from string   inject output values from file into outputs (default "")
      --show strings                show section [header, inputs, outputs, providers, requirements]
      --show-all                    show all sections (default true)
      --sort                        sort items (default true)
      --sort-by-required            sort items by name and print required ones first (default false)
      --sort-by-type                sort items by type of them (default false)
  -v, --version                     version for terraform-docs

Use "terraform-docs [command] --help" for more information about a command.
