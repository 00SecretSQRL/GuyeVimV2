{ pkgs, ... }:
let
  debugpyPython = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  extraPackages = [
    pkgs.lldb
    pkgs.delve
  ];

  plugins.dap-ui = {
    enable = true;
    lazyLoad.settings.cmd = [ "DapUILoad" ];
  };

  plugins.dap = {
    enable = true;
    lazyLoad.settings.keys = [
      {
        __unkeyed-1 = "<leader>db";
        __unkeyed-2.__raw = "function() require('dap').toggle_breakpoint() end";
        desc = "Toggle breakpoint";
      }
      {
        __unkeyed-1 = "<leader>dc";
        __unkeyed-2.__raw = "function() require('dap').continue() end";
        desc = "Run / continue";
      }
      {
        __unkeyed-1 = "<leader>do";
        __unkeyed-2.__raw = "function() require('dap').step_out() end";
        desc = "Step out";
      }
      {
        __unkeyed-1 = "<leader>dl";
        __unkeyed-2.__raw = "function() require('dap').run_last() end";
        desc = "Run last";
      }
      {
        __unkeyed-1 = "<leader>dt";
        __unkeyed-2.__raw = "function() require('dap').terminate() end";
        desc = "Terminate";
      }
      {
        __unkeyed-1 = "<leader>dB";
        __unkeyed-2.__raw = "function() require('dap').set_breakpoint(vim.fn.input('Condition: ')) end";
        desc = "Conditional breakpoint";
      }
      {
        __unkeyed-1 = "<leader>dr";
        __unkeyed-2.__raw = "function() require('dap').repl.toggle() end";
        desc = "Toggle REPL";
      }
      {
        __unkeyed-1 = "<leader>du";
        __unkeyed-2.__raw = "function() require('lz.n').trigger_load('nvim-dap-ui'); require('dapui').toggle() end";
        desc = "Toggle debug UI";
      }
      {
        __unkeyed-1 = "<leader>de";
        __unkeyed-2.__raw = "function() require('lz.n').trigger_load('nvim-dap-ui'); require('dapui').eval() end";
        mode = [
          "n"
          "v"
        ];
        desc = "Evaluate expression";
      }
      {
        __unkeyed-1 = "<leader>dn";
        __unkeyed-2.__raw = "function() require('dap').step_over() end";
        desc = "Step over";
      }
      {
        __unkeyed-1 = "<leader>di";
        __unkeyed-2.__raw = "function() require('dap').step_into() end";
        desc = "Step into";
      }
    ];
    configurations =
      let
        pickProgram = prompt: {
          __raw = "function() return vim.fn.input('${prompt}', vim.fn.getcwd() .. '/', 'file') end";
        };
      in
      {
        rust = [
          {
            name = "Launch executable";
            type = "lldb";
            request = "launch";
            program = pickProgram "Executable: ";
            cwd = "\${workspaceFolder}";
            stopOnEntry = false;
          }
        ];
        go = [
          {
            name = "Debug package";
            type = "delve";
            request = "launch";
            program = "\${fileDirname}";
          }
        ];
        python = [
          {
            name = "Launch file";
            type = "python";
            request = "launch";
            program = "\${file}";
          }
        ];
      };
    # UI opens when a session starts and closes when it ends.
    luaConfig.post = ''
      local dap = require('dap')
      dap.listeners.after.event_initialized['dapui_open'] = function()
        require('lz.n').trigger_load('nvim-dap-ui')
        require('dapui').open()
      end
      dap.listeners.before.event_terminated['dapui_close'] = function()
        if package.loaded['dapui'] then require('dapui').close() end
      end
      dap.listeners.before.event_exited['dapui_close'] = function()
        if package.loaded['dapui'] then require('dapui').close() end
      end
    '';
    adapters.servers.delve = {
      port = "\${port}";
      executable = {
        command = "dlv";
        args = [
          "dap"
          "-l"
          "127.0.0.1:\${port}"
        ];
      };
    };
    adapters.executables = {
      lldb.command = "lldb-dap";
      python = {
        command = "${debugpyPython}/bin/python";
        args = [
          "-m"
          "debugpy.adapter"
        ];
      };
    };
  };
}
