@{
    Servers = @{
        filesystem = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-filesystem\dist\index.js'
            Args        = @('C:\Users\Gabi')
            AlwaysAllow = @('search_files', 'edit_file', 'read_multiple_files')
            Disabled    = $false
        }

        playwright = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@playwright\mcp\cli.js'
            Args        = @()
            AlwaysAllow = @(
                'browser_close',
                'browser_resize',
                'browser_console_messages',
                'browser_handle_dialog',
                'browser_evaluate',
                'browser_file_upload',
                'browser_fill_form',
                'browser_install',
                'browser_type',
                'browser_navigate',
                'browser_navigate_back',
                'browser_take_screenshot',
                'browser_network_requests',
                'browser_snapshot',
                'browser_click',
                'browser_drag',
                'browser_hover',
                'browser_select_option',
                'browser_tabs'
            )
            Disabled    = $false
        }

        memory = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-memory\dist\index.js'
            Args        = @()
            Disabled    = $false
        }

        sequentialthinking = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@modelcontextprotocol\server-sequential-thinking\dist\index.js'
            Args        = @()
            AlwaysAllow = @('sequentialthinking')
            Disabled    = $false
        }

        context7 = @{
            Mode        = 'Launcher'
            Runtime     = 'NodeScript'
            CommandPath = 'C:\Users\Gabi\.agent-runtime\mcp\node_modules\@upstash\context7-mcp\dist\index.js'
            Args        = @()
            Disabled    = $false
        }

        'ai-agents-swiss-knife' = @{
            Mode        = 'Launcher'
            Runtime     = 'Python'
            CommandPath = 'C:\Users\Gabi\.codex\ai-agents-swiss-knife\.venv\Scripts\python.exe'
            Args        = @('C:\Users\Gabi\.codex\ai-agents-swiss-knife\server\mcp_bridge.py')
            EnvMap      = @{
                MCP_BASE_URL          = '${MCP_AI_AGENTS_SWISS_KNIFE_BASE_URL}'
                MCP_AUTOSTART_BACKEND = '1'
            }
            OptionalEnv = @{
                MCP_AI_AGENTS_SWISS_KNIFE_BASE_URL = 'http://127.0.0.1:8000'
            }
            Disabled    = $true
            AlwaysAllow = @()
        }

        'Agent Maestro' = @{
            Mode          = 'Endpoint'
            TransportType = 'streamable-http'
            Url           = '${MCP_AGENT_MAESTRO_URL}'
            OptionalEnv   = @{
                MCP_AGENT_MAESTRO_URL = 'http://localhost:23334/mcp'
            }
            AlwaysAllow   = @('Execute Roo Tasks')
            Timeout       = 900
            Disabled      = $false
            HealthUrl     = '${MCP_AGENT_MAESTRO_URL}'
        }

        github = @{
            Mode        = 'Launcher'
            Runtime     = 'Docker'
            Args        = @(
                'run',
                '-i',
                '--rm',
                '-e', 'GITHUB_PERSONAL_ACCESS_TOKEN',
                '-e', 'GITHUB_TOOLSETS',
                '-e', 'GITHUB_READ_ONLY',
                'ghcr.io/github/github-mcp-server'
            )
            RequiredEnv = @('GITHUB_PERSONAL_ACCESS_TOKEN')
            OptionalEnv = @{
                GITHUB_TOOLSETS  = ''
                GITHUB_READ_ONLY = '0'
            }
            Disabled    = $false
            AlwaysAllow = @()
        }

        sentry = @{
            Mode        = 'Launcher'
            Runtime     = 'Uvx'
            Args        = @('mcp-server-sentry', '--auth-token', '${SENTRY_AUTH_TOKEN}')
            RequiredEnv = @('SENTRY_AUTH_TOKEN')
            Disabled    = $false
        }

        notion = @{
            Mode        = 'Launcher'
            Runtime     = 'Npx'
            Args        = @('@notionhq/notion-mcp-server')
            RequiredEnv = @('NOTION_API_TOKEN')
            EnvMap      = @{
                OPENAPI_MCP_HEADERS = '{"Authorization":"Bearer ${NOTION_API_TOKEN}","Notion-Version":"2022-06-28"}'
            }
            Disabled    = $false
        }

        e2b = @{
            Mode        = 'Launcher'
            Runtime     = 'Npx'
            Args        = @('@e2b/mcp-server')
            RequiredEnv = @('E2B_API_KEY')
            EnvMap      = @{
                E2B_API_KEY = '${E2B_API_KEY}'
            }
            Disabled    = $false
        }

        firebase = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('firebase-tools@14.15.2', 'experimental:mcp')
            Disabled = $false
        }

        'ida-pro' = @{
            Mode     = 'Launcher'
            Runtime  = 'Uvx'
            Args     = @('--from', 'git+https://github.com/mrexodia/ida-pro-mcp.git@f0af9fba733fb60fc13365b297b10c82db3771d7', 'ida-pro-mcp')
            Disabled = $false
        }

        'n8n-mcp' = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('n8n-mcp@2.12.2')
            EnvMap   = @{
                MCP_MODE               = 'stdio'
                LOG_LEVEL              = 'error'
                DISABLE_CONSOLE_OUTPUT = 'true'
            }
            Disabled = $false
        }

        puppeteer = @{
            Mode     = 'Launcher'
            Runtime  = 'Npx'
            Args     = @('@modelcontextprotocol/server-puppeteer')
            Disabled = $false
        }
    }
}
