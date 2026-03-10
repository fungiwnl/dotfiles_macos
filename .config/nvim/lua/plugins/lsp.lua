return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      -- Disable legacy tsserver
      tsserver = { enabled = false },
      ts_ls = { enabled = false },

      vtsls = {
        -- Force project-based loading (prevents multiple instances)
        single_file_support = false,

        -- Monorepo root detection
        --root_dir = function(fname)
        --  return require("lspconfig.util").root_pattern("pnpm-workspace.yaml", "lerna.json", "nx.json", "turbo.json")(
        --    fname
        --  ) or require("lspconfig.util").root_pattern("tsconfig.json", "jsconfig.json", "package.json")(fname)
        --end,

        filetypes = {
          "javascript",
          "javascriptreact",
          "javascript.jsx",
          "typescript",
          "typescriptreact",
          "typescript.tsx",
        },

        settings = {
          complete_function_calls = true,
          vtsls = {
            enableMoveToFileCodeAction = true,
            autoUseWorkspaceTsdk = true,
            tsserver = {
              globalPlugins = {},
            },
            experimental = {
              completion = {
                enableServerSideFuzzyMatch = false,
              },
              maxInlayHintLength = 30,
            },
          },
          typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = {
              completeFunctionCalls = true,
            },
            preferences = {
              includePackageJsonAutoImports = "auto",
            },
            tsserver = {
              maxTsServerMemory = 8192,
              watchOptions = {
                watchFile = "useFsEvents",
                watchDirectory = "useFsEvents",
                fallbackPolling = "dynamicPriorityPolling",
              },
            },
            inlayHints = {
              enumMemberValues = { enabled = false },
              functionLikeReturnTypes = { enabled = false },
              parameterNames = { enabled = "none" },
              parameterTypes = { enabled = false },
              propertyDeclarationTypes = { enabled = false },
              variableTypes = { enabled = false },
            },
          },
        },

        keys = {
          {
            "gD",
            function()
              local params = vim.lsp.util.make_position_params()
              LazyVim.lsp.execute({
                command = "typescript.goToSourceDefinition",
                arguments = { params.textDocument.uri, params.position },
                open = true,
              })
            end,
            desc = "Goto Source Definition",
          },
          {
            "gR",
            function()
              LazyVim.lsp.execute({
                command = "typescript.findAllFileReferences",
                arguments = { vim.uri_from_bufnr(0) },
                open = true,
              })
            end,
            desc = "File References",
          },
          {
            "<leader>co",
            LazyVim.lsp.action["source.organizeImports"],
            desc = "Organize Imports",
          },
          {
            "<leader>cM",
            LazyVim.lsp.action["source.addMissingImports.ts"],
            desc = "Add missing imports",
          },
          {
            "<leader>cu",
            LazyVim.lsp.action["source.removeUnused.ts"],
            desc = "Remove unused imports",
          },
          {
            "<leader>cD",
            LazyVim.lsp.action["source.fixAll.ts"],
            desc = "Fix all diagnostics",
          },
          {
            "<leader>cV",
            function()
              LazyVim.lsp.execute({ command = "typescript.selectTypeScriptVersion" })
            end,
            desc = "Select TS workspace version",
          },
        },
      },
    },

    setup = {
      tsserver = function()
        return true -- disable tsserver
      end,

      vtsls = function(_, opts)
        Snacks.util.lsp.on({ name = "vtsls" }, function(buffer, client)
          client.commands["_typescript.moveToFileRefactoring"] = function(command, ctx)
            local action, uri, range = unpack(command.arguments)

            local function move(newf)
              client.request("workspace/executeCommand", {
                command = command.command,
                arguments = { action, uri, range, newf },
              })
            end

            local fname = vim.uri_to_fname(uri)
            client.request("workspace/executeCommand", {
              command = "typescript.tsserverRequest",
              arguments = {
                "getMoveToRefactoringFileSuggestions",
                {
                  file = fname,
                  startLine = range.start.line + 1,
                  startOffset = range.start.character + 1,
                  endLine = range["end"].line + 1,
                  endOffset = range["end"].character + 1,
                },
              },
            }, function(_, result)
              local files = result and result.body and result.body.files or {}
              table.insert(files, 1, "Enter new path...")
              vim.ui.select(files, {
                prompt = "Select move destination:",
                format_item = function(f)
                  return vim.fn.fnamemodify(f, ":~:.")
                end,
              }, function(f)
                if f and f:find("^Enter new path") then
                  vim.ui.input({
                    prompt = "Enter move destination:",
                    default = vim.fn.fnamemodify(fname, ":h") .. "/",
                    completion = "file",
                  }, function(newf)
                    if newf then
                      move(newf)
                    end
                  end)
                elseif f then
                  move(f)
                end
              end)
            end)
          end
        end)

        opts.settings.javascript =
          vim.tbl_deep_extend("force", {}, opts.settings.typescript, opts.settings.javascript or {})
      end,
    },
  },
}
