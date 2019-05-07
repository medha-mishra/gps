"""
This plugin creates buttons on the toolbar to conveniently
debug, and run programs on GNATemulator.

The following is required:
 - the GNATemulator for your target should be present on the PATH, if not the
   buttons won't be displayed.
"""

import GPS
from modules import Module
import workflows.promises as promises
import workflows
from os_utils import locate_exec_on_path
from gps_utils.console_process import Console_Process


project_attributes = """
  <project_attribute
   package="emulator"
   name="Debug_Port"
   label="Debug port"
   editor_page="GNATemulator"
   hide_in="wizard library_wizard"
   description="Port used by GNATemulator to debug."
  >
    <string/>
  </project_attribute>
  <project_attribute
   package="emulator"
   name="Board"
   label="Board"
   editor_page="GNATemulator"
   hide_in="wizard library_wizard"
   """ + \
    "description='If GNATemulator provides multiple emulations for the" + \
    " target platform, use this option to select a specific board. Use" + \
    " `gnatemu --help` to get the list of boards.'" + """
  >
    <string/>
  </project_attribute>
  <project_attribute
   package="emulator"
   name="Switches"
   label="Switches"
   editor_page="GNATemulator"
   hide_in="wizard library_wizard"
   description="A list of switches processed before the command line switches"
   list="true"
  >
    <string/>
  </project_attribute>

  <!-- This is a model for runnning test-driver executables generated by
  GNATtest on GNATemulator -->
  <target-model name="Run emulator" category="">
    <description>Run GNATemulator</description>
    <is-run>FALSE</is-run>
    <command-line>
      <arg>%E</arg>
    </command-line>
    <server>Execution_Server</server>
    <iconname>gps-run-symbolic</iconname>

    <switches command="%(tool_name)s" columns="1" separator="=">
    </switches>
  </target-model>

  <target model="Run emulator" category="Run"
          name="Run GNATemulator"
          messages_category="test-driver">
    <visible>FALSE</visible>
    <in-menu>TRUE</in-menu>
    <in-toolbar>TRUE</in-toolbar>
    <in-contextual-menus-for-projects>TRUE</in-contextual-menus-for-projects>
    <launch-mode>MANUALLY</launch-mode>
    <target-type>executable</target-type>
    <command-line>
      <arg>%python(gnatemulator.GNATemulator.get_gnatemu_name())</arg>
      <arg>-P%PP</arg>
    </command-line>
    <iconname>gps-gnattest-run</iconname>
  </target>
"""

# This has to be done at GPS start, before the project is actually loaded.
GPS.parse_xml(project_attributes)


def log(msg):
    GPS.Logger("GNATemulator").log(msg)


class GNATemulator(Module):

    # List of targets
    # These are created lazily the first time we find the necessary tools on
    # the command line. This is done so that we do not have to toggle the
    # visibility of these build targets too often, since that also trigger
    # the reparsing of Makefiles, for instance, and a refresh of all GUI
    # elements related to any build target.
    __buildTargets = []

    def __create_targets_lazily(self):
        active = GNATemulator.gnatemu_on_path()

        if not self.__buildTargets:
            targets_def = [
                ["Run with Emulator", "run-with-emulator",
                 GNATemulator.build_and_run,
                 "gps-emulatorloading-run-symbolic"],
                ["Debug with Emulator", "debug-with-emulator",
                 GNATemulator.build_and_debug,
                 "gps-emulatorloading-debug-symbolic"]]

            for target in targets_def:
                if active:
                    workflows.create_target_from_workflow(
                        target[0], target[1], target[2], target[3],
                        parent_menu='/Build/Emulator/%s/' % target[0])
                try:
                    self.__buildTargets.append(GPS.BuildTarget(target[0]))
                except Exception:
                    return

        if active:
            for b in self.__buildTargets:
                b.show()
        else:
            for b in self.__buildTargets:
                b.hide()

    @staticmethod
    def get_gnatemu_name():
        target = GPS.get_target()
        if target:
            prefix = target + '-'
        else:
            prefix = ""

        return prefix + "gnatemu"

    @staticmethod
    def gnatemu_on_path():
        bin = GNATemulator.get_gnatemu_name()

        gnatemu = locate_exec_on_path(bin)
        return gnatemu != ''

    @staticmethod
    def generate_gnatemu_command(gnatemu, args):
        """ Returns a list containing a command line calling gnatemu. """
        sv = GPS.Project.scenario_variables()
        var_args = ["-X%s=%s" % (k, v) for k, v in sv.items()] if sv else []
        command = [gnatemu]
        proj = GPS.Project.root()
        if proj:
            command.append("-P%s" % proj.file().path)
        command += var_args + args
        return command

    @staticmethod
    def run_gnatemu(args, in_console=True):
        command = GNATemulator.generate_gnatemu_command(
            GNATemulator.get_gnatemu_name(), args)
        GPS.Console("Messages").write("Running in emulator: %s\n" %
                                      (' '.join(command)))
        #  - We open GNATemu in a console by default.
        #  - If specified, we use the BuildTarget for running GNATemu instead.
        #  - Don't close the console when GNAtemu exits so we have time to see
        #    the results
        #  - GNATemu should be in the task manager
        if in_console:
            yield Console_Process(command=command, force=True,
                                  close_on_exit=False, task_manager=True,
                                  manage_prompt=False)
        else:
            builder = promises.TargetWrapper("Run GNATemulator")
            yield builder.wait_on_execute(extra_args=args)

    @staticmethod
    def __error_exit(msg=""):
        """ Emit an error and reset the workflows """
        GPS.Console("Messages").write(
            msg + " [workflow stopped]",
            mode="error")

    # Launch the BuildTarget for building with
    # the given adb file as the main file
    @staticmethod
    def build(main_name):
        """
        Generator to build the program.
        """

        if main_name is None:
            GNATemulator.__error_exit(msg="Main not specified")
            return

        # STEP 1.5 Build it
        log("Building Main %s..." % main_name)
        builder = promises.TargetWrapper("Build Main")
        r0 = yield builder.wait_on_execute(main_name)
        if r0 is not 0:
            GNATemulator.__error_exit(msg="Build error.")
            raise RuntimeError("Build failed.")

        log("... done.")

    #
    # The following are workflows #
    #

    @staticmethod
    def build_and_run(main_name, in_console=True):
        """
        Generator to build and run the program in the emulator.
        """

        if main_name is None:
            GNATemulator.__error_exit(msg="Main not specified")
            return

        # STEP 1.5 Build it
        try:
            yield GNATemulator.build(main_name)
        except RuntimeError:
            return

        # Get the name of the generated binary
        bin_name = GPS.File(main_name).executable_path.path

        # STEP 2 launch with Emulator
        yield GNATemulator.run_gnatemu([bin_name], in_console)

    @staticmethod
    def build_and_debug(main_name):
        """
        Generator to debug a program launched in the emulator.
        """

        # STEP 1.0 get main name
        if main_name is None:
            GNATemulator.__error_exit(msg="Main not specified.")
            return

        # STEP 1.5 Build it

        try:
            yield GNATemulator.build(main_name)
        except RuntimeError:
            # Build error, we stop there
            return

        binary = GPS.File(main_name).executable_path.path
        # STEP 2 Switch to the "Debug" perspective To have GNATemu console in
        # the debugger perspective.

        GPS.MDI.load_perspective("Debug")

        # STEP 2 load with Emulator
        debug_port = GPS.Project.root().get_attribute_as_string(
            package="Emulator", attribute="Debug_Port")

        # TODO: remove this fall-back once GNATemulator supports the
        # new 'Debug_Port' attribute (Fabien's task)
        if debug_port == "":
            debug_port = "1234"

        yield GNATemulator.run_gnatemu(["--freeze-on-startup",
                                        "--gdb=%s" % debug_port,
                                        binary])

        log("... done.")

        # STEP 3 launch the debugger
        try:
            debugger_promise = promises.DebuggerWrapper(
                GPS.File(binary),
                remote_target="localhost:" + debug_port,
                remote_protocol="remote")
        except Exception:
            GNATemulator.__error_exit("Could not initialize the debugger.")
            return

        # block execution until debugger is free
        r3 = yield debugger_promise.wait_and_send(block=True)
        if not r3:
            GNATemulator.__error_exit("Could not initialize the debugger.")
            return

        log("... done.")

    def setup(self):
        self.__create_targets_lazily()

    def project_view_changed(self):
        self.__create_targets_lazily()
