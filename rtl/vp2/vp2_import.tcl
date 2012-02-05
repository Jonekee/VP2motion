# version: 10.1.03
# ProjectNavigator SourceControl recreation script
#
# This script is text version of significant (but possibly not all)
# the information contained in the ISE project file.  It is generated
# and used by the ProjectNavigator application's source control
# import feature.
#
# When using this script from the command line to recreate the ISE
# project, it should first be sourced from within an xtclsh shell.
# Next, the import procedure should be called to perform the import.
# When calling the import procedure, pass the new project directory
# and the source directory.  If neither are specified, the current
# working directory is assumed for both.
#
# Internally this script has two file lists. One variable (import_files)
# has the set of files to copy into the project directory.  The other
# variable (user_files) has the set of files to add into the project.
#
#
# This script is not intended for direct customer editing.
#
# Copyright 2006, Xilinx, Inc.
#


#  Helper to copy files from the source staging area
#  back into the destination work area.
#  This proc will be call for each file copied.
#  While not supported, one could do interesting things with this
#  proc, since each file hits it.
proc CopyIn { srcfile work_area copy_option } {
   set staging_area [pwd]
   if { [ expr { [ file pathtype $srcfile ] == "absolute"   || \
                 [string index $srcfile 0 ] == "/"        || \
                 [string index $srcfile 1 ] == ":"        } ] } {
       set workfile $srcfile
   } else {
       set workfile [ file join $work_area $srcfile ]
   }
   if { $copy_option == "flatten" } {
       set stagefile [ file join $staging_area [ file tail $srcfile ] ]
   } elseif { [ file pathtype $srcfile ] != "relative" } {
       set srcfile [ string map {: _} $srcfile ]
       set stagefile [ file join $staging_area absolute $srcfile ]
   } elseif { [ expr { $copy_option == "absremote" } && { [string equal -length 2 $srcfile ".." ] } ] } {
       set stagefile [ file join $staging_area outside_relative [ string map {.. up} $srcfile ] ]
   } else {
       set srcfile [ string map {: _} $srcfile ]
       set stagefile [ file join $staging_area $srcfile ]
   }

   set stagefile [ file normalize $stagefile ]
   set workfile [ file normalize $workfile ]

   if { [ file exists $stagefile ] } {
      if { $stagefile != $workfile } {
         file mkdir [ file dirname $workfile ]
         file copy -force $stagefile $workfile
      }
   } else { WARN "\"$stagefile\" does not exist for import copy." }
}

proc ERR { msg } {
   puts "ERROR: $msg"
}

proc WARN { msg } {
   puts "WARNING: $msg"
}

proc INFO { msg } {
   puts "$msg"
}

# Helper that returns 1 if the string is blank, otherwise 0.
proc IsBlank { str } {
   if { [string length $str] == 0 } {
      return 1
   }
   return 0
}

# Helper for determining whether a value is 'NULL'.
# Returns 1 if the value is 0; returns 0 if the value is anything else.
proc IsNull { val } {
   if { $val == 0 } {
      return 1
   }
   return 0
}

proc HandleException { script { msg "" } } {
   set catch_result [catch {
      uplevel 1 $script
   } RESULT]
   if {$catch_result} {
      if {![IsBlank $msg]} {
         ERR $msg
      }
      INFO "$RESULT"
      INFO "$::errorInfo"
   }
}

# These two procs help to load shared libraries in a platform
# independent way.
proc _LoadLibrary {name} {
   set libExt [info sharedlibextension]
   set libFullName "$name$libExt"
   HandleException {
      load $libFullName
   } "A problem occured loading library $libFullName."
}

proc _LoadFactoryLibrary {Factory} {
   HandleException {
      Xilinx::Cit::FactoryLoad $Factory
   } "A problem occured loading library $Factory."
}

_LoadLibrary libCit_CoreStub
_LoadLibrary libPrjrep_CommonStub
_LoadFactoryLibrary libPrjrep_Common
_LoadLibrary libDpm_SupportStub
_LoadLibrary libDpm_PnfStub
_LoadLibrary libDpm_DefnDataStub
_LoadLibrary libDpm_DesignDataStub
_LoadLibrary libDpm_HdlStub
_LoadLibrary libPrjrep_RepositoryStub
_LoadLibrary libCitI_CoreStub
_LoadLibrary libHdcI_HdcHDProjectStub
_LoadLibrary libTcltaskI_TaskStub
_LoadLibrary libCommonI_CommonStub
_LoadFactoryLibrary libTcltask_Helpers
_LoadFactoryLibrary libHdcC_HDProject
_LoadLibrary libHdcI_HdcContainerStub
_LoadLibrary libGuiI_Stub

#  Helper to exectute code only when the (pointer) variable name is valid.
proc OnOkPtr { var_name script } {
   if { [ uplevel info exists $var_name ] } {
      upvar $var_name var
      if { $var != 0 } { return [ uplevel $script ] }
   }
}

#  Helper to exectute code only when the (pointer) variable name is 0.
proc OnNullPtr { var_name script } {
   if { [ uplevel info exists $var_name ] } {
      upvar $var_name var
      if { $var == 0 } { return [ uplevel $script ] }
   }
}

#  Helper to exectute code only when the value of variable name is 1.
proc OnSuccess { var_name script } {
   if { $val != 0 } { return [ uplevel $script ] }
}

#  Helper to exectute code only when the value of variable name is 0.
proc OnFail { val script } {
   if { $val != 1 } { return [ uplevel $script ] }
}

#  Helper to get a component interface.
proc GetInterface { iUnk id { name "" } } {
   if {$iUnk == 0} { return 0 }
   set iIface [ $iUnk GetInterface $id ]
   OnNullPtr iIface {
      if {![IsBlank $name]} {
         ERR " Could not get the \"$name\" interface."
      }
   }
   return $iIface
}

#  Helper to create a component and return one of its interfaces.
proc CreateComponent { compId ifaceId { name "" } } {
   set iUnk [ ::Xilinx::Cit::FactoryCreate $compId ]
   set iIface [ GetInterface $iUnk $ifaceId ]
   OnNullPtr iIface {
      if {![IsBlank $name]} { ERR "Could not create a \"$name\" component." }
   }
   return $iIface
}

#  Helper to release an object
proc Release { args } {
   foreach iUnk $args {
      set i_refcount [ GetInterface $iUnk $::xilinx::Prjrep::IRefCountID ]
      OnNullPtr i_refcount { set i_refcount [ GetInterface $iUnk $::xilinx::CommonI::IRefCountID ] }
      OnOkPtr i_refcount { $i_refcount Release }
   }
}

#  Helper to loop over IIterator based pointers.
proc ForEachIterEle { _ele_var_name _iter script } {
   if {$_iter == 0} { return 0 }
   upvar $_ele_var_name ele
   for { $_iter First } { ![ $_iter IsEnd ] } { $_iter Next }  {
      set ele [ $_iter CurrentItem ]
      set returned_val [ uplevel $script ] 
   }
}

#  Helper to get the Tcl Project Manager, if possible.
proc GetTclProjectMgr { } {
   set TclProjectMgrId "{7d528480-1196-4635-aba9-639446e4aa59}"
   set iUnk [ Xilinx::CitP::CreateComponent $TclProjectMgrId ]
   if {$iUnk == 0} { return 0 }
   set iTclProjectMgr [ $iUnk GetInterface $::xilinx::TcltaskI::ITclProjectMgrID ]
   OnNullPtr iTclProjectMgr {
      ERR "Could not create a \"TclProjectMgr\" component."
   }
   return $iTclProjectMgr
}

#  Helper to get the current Tcl Project, if one is open.
proc GetCurrentTclProject { } {
   set iTclProject 0
   set iTclProjectMgr [GetTclProjectMgr]
   OnOkPtr iTclProjectMgr {
      set errmsg ""
      $iTclProjectMgr GetCurrentTclProject iTclProject errmsg
   }
   return $iTclProject
}

#  Helper to get the current HDProject, if one is open.
proc GetCurrentHDProject { } {
   set iHDProject 0
   set iTclProjectMgr [GetTclProjectMgr]
   set errmsg ""
   OnOkPtr iTclProjectMgr { $iTclProjectMgr GetCurrentHDProject iHDProject errmsg }
   OnNullPtr iHDProject {
      ERR "Could not get the current HDProject."
   }
   return $iHDProject
}

#  Helper to create a Project Helper.
proc GetProjectHelper { } {
   set ProjectHelperID "{0725c3d2-5e9b-4383-a7b6-a80c932eac21}"
   set iProjHelper [CreateComponent $ProjectHelperID $::xilinx::Dpm::IProjectHelperID "Project Helper"]
   return $iProjHelper
}

#  Helper to find out if a project is currently open.
#  Returns 1 if a project is open, otherwise 0.
proc IsProjectOpen { } {
   set iTclProject [GetCurrentTclProject]
   set isOpen [expr {$iTclProject != 0}]
   Release $iTclProject
   return $isOpen
}

#  Helper to return the lock file for the specified project if there is one.
#  Returns an empty string if there is no lock file on the specified project,
#  or there is no corresponding .ise file
#  This assumes that the project_file is in the current directory.
#  It also assumes project_file does not have a path.
proc GetProjectLockFile { project_file } {
   if { ![ file isfile "$project_file" ] } {
      return 
   }
   INFO "Checking for a lock file for \"$project_file\"."
   set lock_file "__ISE_repository_${project_file}_.lock"
   if { [ file isfile "$lock_file" ] } {
      return $lock_file
   }
   return 
}

#  Helper to back up the project file.
#  This assumes that the project_file is in the current directory.
proc BackUpProject { project_file backup_file } {
   if { ![ file isfile "$project_file" ] } {
      WARN "Could not find \"$project_file\"; the project will not be backed up."
   return 0
   } else {
      INFO "Backing up the project to \"$backup_file\"."
      file copy -force "$project_file" "$backup_file"
   }
   return 1
}

#  Helper to remove the project file so that a new project can be created
#  in its place. Presumably the old project is corrupted and can no longer
#  be opened.
proc RemoveProject { project_file } {
   file delete -force "$project_file"
   # Return failure if the project still exists.
   if { [ file isfile "$project_file" ] } {
      ERR "Could not remove \"$project_file\"; Unable to restore the project."
      return 0
   }
   return 1
}

#  Helper to open a project and return a project facilitator (pointer).
proc OpenFacilProject { project_name } {
   # first make sure the tcl project mgr singleton exists
   GetTclProjectMgr
   # get a Project Helper and open the project.
   set iProjHelper [GetProjectHelper]
   if {$iProjHelper == 0} { return 0 }
   set result [$iProjHelper Open $project_name]
   OnFail $result {
      if {$result == 576460769483292673} {
         ERR "Could not open the project \"$project_name\" because it is locked."
      } else {
         ERR "Could not open the \"$project_name\" project."
      }
      Release $iProjHelper
      set iProjHelper 0
   }
   return $iProjHelper
}

#  Helper to close and release a project.
proc CloseFacilProject { iProjHelper } {
   if {$iProjHelper == 0} { return }
   $iProjHelper Close
   Release $iProjHelper
}

#  Helper to get the Project from the Project Helper.
#  Clients must release this.
proc GetProject { iProjHelper } {
   if {$iProjHelper == 0} { return 0 }
   set dpm_project 0
   $iProjHelper GetDpmProject dpm_project
   set iProject [ GetInterface $dpm_project $xilinx::Dpm::IProjectID ]
   OnNullPtr iProject {
      ERR "Could not get the Project from the Project Helper."
   }
   return $iProject
}

#  Helper to get the File Manager from the Project Helper.
#  Clients must release this.
proc GetFileManager { iProjHelper } {
   set iProject [GetProject $iProjHelper]
   set iFileMgr [ GetInterface $iProject $xilinx::Dpm::IFileManagerID ]
   OnNullPtr iFileMgr {
      ERR "Could not get the File Manager from the Project Helper."
   }
   # Don't release the project here, clients will release it 
   # when they release its IFileManager interface.
   return $iFileMgr
}

#  Helper to get the Source Library Manager from the Project Helper.
#  Clients must release this.
proc GetSourceLibraryManager { iProjHelper } {
   set iProject [GetProject $iProjHelper]
   set iSourceLibraryMgr [ GetInterface $iProject $xilinx::Dpm::ISourceLibraryManagerID ]
   OnNullPtr iSourceLibraryMgr {
      ERR "Could not get the Source Library Manager from the Project Helper."
   }
   # Don't release the project here, clients will release it 
   # when they release its IFileManager interface.
   return $iSourceLibraryMgr
}

#  Helper to get the ProjSrcHelper from the Project Helper.
#  Clients must NOT release this.
proc GetProjSrcHelper { iProjHelper } {
   set iSrcHelper [ GetInterface $iProjHelper $::xilinx::Dpm::IProjSrcHelperID IProjSrcHelper ]
   OnNullPtr iSrcHelper {
      ERR "Could not get the ProjSrcHelper from the Project Helper."
   }
   return $iSrcHelper
}

#  Helper to get the ScratchPropertyManager from the Project Helper.
#  Clients must NOT release this.
proc GetScratchPropertyManager { iProjHelper } {
   set iPropTableFetch [ GetInterface $iProjHelper $xilinx::Dpm::IPropTableFetchID IPropTableFetch ]
   set prop_table_comp 0
   OnOkPtr iPropTableFetch {
      $iPropTableFetch GetPropTable prop_table_comp
   }
   set iScratch [ GetInterface $prop_table_comp $xilinx::Dpm::IScratchPropertyManagerID ]
   OnNullPtr iScratch {
      ERR "Could not get the Scratch Property Manager from the Project Helper."
   }
   return $iScratch
}

#  Helper to get the Design from the Project Helper.
#  Clients must release this.
proc GetDesign { iProjHelper } {
   set iProject [GetProject $iProjHelper]
   set iDesign 0
   OnOkPtr iProject { $iProject GetDesign iDesign }
   OnNullPtr iDesign {
      ERR "Could not get the Design from the Project Helper."
   }
   Release $iProject
   return $iDesign
}

#  Helper to get the Data Store from the Project Helper.
#  Clients must NOT release this.
proc GetDataStore { iProjHelper } {
   set iDesign [ GetDesign $iProjHelper]
   set iDataStore 0
   OnOkPtr iDesign { $iDesign GetDataStore iDataStore }
   OnNullPtr iDataStore {
      ERR "Could not get the Data Store from the Project Helper."
   }
   Release $iDesign
   return $iDataStore
}

#  Helper to get the View Manager from the Project Helper.
#  Clients must NOT release this.
proc GetViewManager { iProjHelper } {
   set iDesign [ GetDesign $iProjHelper]
   set iViewMgr [ GetInterface $iDesign $xilinx::Dpm::IViewManagerID ]
   OnNullPtr iViewMgr {
      ERR "Could not get the View Manager from the Project Helper."
   }
   # Don't release the design here, clients will release it 
   # when they release its IViewManager interface.
   return $iViewMgr
}

#  Helper to get the Property Manager from the Project Helper.
#  Clients must release this.
proc GetPropertyManager { iProjHelper } {
   set iDesign [ GetDesign $iProjHelper]
   set iPropMgr 0
   OnOkPtr iDesign { $iDesign GetPropertyManager iPropMgr }
   OnNullPtr iPropMgr {
      ERR "Could not get the Property Manager from the Project Helper."
   }
   Release $iDesign
   return $iPropMgr
}

#  Helper to find a property template, based on prop_name
#  Clients must NOT release this.
proc GetPropertyTemplate { iProjHelper prop_name } {
   set iPropTempl 0
   set iUnk 0
   set iDefdataId 0
   set iPropTemplStore 0
   set iDataStore [GetDataStore $iProjHelper]
   OnOkPtr iDataStore { $iDataStore GetComponentByName $prop_name iUnk }
   OnOkPtr iUnk { set iDefdataId [ GetInterface $iUnk $xilinx::Dpm::IDefDataIdID IDefDataId ] }
   OnOkPtr iDefdataId {
      set iPropTemplStore [ GetInterface $iDataStore $xilinx::Dpm::IPropertyTemplateStoreID IPropertyTemplateStore ]
   }
   OnOkPtr iPropTemplStore { $iPropTemplStore GetPropertyTemplate $iDefdataId iPropTempl }
   OnNullPtr iPropTempl {
      WARN "Could not get the property template for \"$prop_name\"."
   }
   return $iPropTempl
}

#  Helper to get a component's name.
proc GetName { iUnk } {
   set name ""
   set iName [ GetInterface $iUnk $xilinx::Prjrep::INameID IName ]
   OnOkPtr iName { $iName GetName name }
   return $name
}

#  Helper to get the name of a view's type.
proc GetViewTypeName { iView } {
   set typeName ""
   set iType 0
   set iDefdataType 0
   OnOkPtr iView { $iView GetType iType }
   OnOkPtr iType {
      set iDefdataType [ GetInterface $iType $xilinx::Dpm::IDefDataIdID IDefDataId ]
   }
   OnOkPtr iDefdataType { $iDefdataType GetID typeName }
   return $typeName
}

#  Helper to find a view and return its context.
#  Must clients release this?
proc GetViewContext { iProjHelper view_id view_name } {
   # Simply return if the view_id or view_name is empty.
   if { [IsBlank $view_id] || [IsBlank $view_name] } { return 0 }
   set foundview 0
   set viewiter 0
   set iViewMgr [GetViewManager $iProjHelper]
   OnOkPtr iViewMgr { $iViewMgr GetViews viewiter }
   ForEachIterEle view $viewiter {
      set typeName [GetViewTypeName $view]
      set name [GetName $view]
      if { [ string equal $name $view_name ] && [ string equal $view_id $typeName ] } {
         set foundview $view
      }
   }
   set context [ GetInterface $foundview $xilinx::Dpm::IPropertyContextID ]
   OnNullPtr context {
      WARN "Could not get the context for view \"$view_id\":\"$view_name\"."
   }
   return $context
}

#  Helper to get a string property instance from the property manager.
proc GetStringPropertyInstance { iProjHelper simple_id } {
   set iPropMgr [GetPropertyManager $iProjHelper]
   if {$iPropMgr == 0} { return 0 }
   set iPropInst 0
   $iPropMgr GetStringProperty $simple_id iPropInst
   OnNullPtr iPropInst { WARN "Could not get the string property instance $simple_id." }
   Release $iPropMgr
   return $iPropInst
}

#  Helper to get a property instance from the property manager.
proc GetPropertyInstance { iProjHelper view_name view_id prop_name } {
   set iPropInst 0
   set iPropTempl [ GetPropertyTemplate $iProjHelper $prop_name ]
   if {$iPropTempl == 0} { return 0 }
   set context [ GetViewContext $iProjHelper $view_id $view_name ]
   set iPropMgr [GetPropertyManager $iProjHelper]
   if {$iPropMgr == 0} { return 0 }
   $iPropMgr GetPropertyInstance $iPropTempl $context iPropInst
   OnNullPtr iPropInst {
      if { ![IsBlank $view_id] && ![IsBlank $view_name] } {
         WARN "Could not get the context sensitive property instance $prop_name."
      } else {
         WARN "Could not get the property instance $prop_name."
      }
   }
   Release $iPropMgr
   return $iPropInst
}

#  Helper to store properties back into the property manager.
proc RestoreProcessProperties { iProjHelper process_props } {
   INFO "Restoring process properties"
   foreach { unused view_name view_id simple_id prop_name prop_val } $process_props {
      set iPropInst 0
      if {![IsBlank $simple_id]} {
         set iPropInst [ GetStringPropertyInstance $iProjHelper $simple_id ]
      } else {
         set iPropInst [ GetPropertyInstance $iProjHelper $view_name $view_id $prop_name ]
      }
      OnOkPtr iPropInst {
         OnFail [ $iPropInst SetStringValue "$prop_val" ] {
            WARN "Could not set the value of the $prop_name property to \"$prop_val\"."
         }
      }
      Release $iPropInst
   }
}

#  Helper to recreate partitions from the variable name with
#  a list of instance names.
proc RestorePartitions { namelist } {
   INFO "Restoring partitions."
   set iHDProject [ GetCurrentHDProject ]
   OnOkPtr iHDProject {
      foreach name $namelist {
         set iPartition [ $iHDProject CreatePartition "$name" ]
      }
   }
}

#  Helper to create and populate a library
#
proc CreateLibrary { iProjHelper libname filelist } {

   set iLibMgr [ GetSourceLibraryManager $iProjHelper ]
   set iFileMgr [ GetFileManager $iProjHelper ]

   if {$iLibMgr == 0} { return 0 }
   if {$iFileMgr == 0} { return 0 }

   $iLibMgr CreateSourceLibrary "libname" ilib

   OnOkPtr ilib {
      foreach filename $filelist {
         set argfile [ file normalize "$filename" ]
         set found 0
         set fileiter 0
         $iFileMgr GetFiles fileiter
         ForEachIterEle ifile $fileiter {
            set path ""
            set file ""
            $ifile getPath path file
            set currentfile [ file normalize [ file join "$path" "$file" ] ]
            if { $currentfile == $argfile } {
               set found 1
               $ilib AddFile ifile
               break
            }
         }
         OnNullPtr found {
            WARN "Could not add the file \"$filename\" to the library \"$libname\"."
         }
      }
   }
}

#  Helper to create source libraries and populate them.
proc RestoreSourceLibraries { iProjHelper libraries } {
   INFO "Restoring source libraries."
   foreach { libname filelist } $libraries {
      CreateLibrary $iProjHelper "$libname" $filelist
   }
}

# Helper to add user files to the project using the PnF.
proc AddUserFiles { iProjHelper files } {
   INFO "Adding User files."
   set iconflict 0
   set iSrcHelper [ GetProjSrcHelper $iProjHelper ]
   if {$iSrcHelper == 0} { return 0 }
   foreach filename $files {
      INFO "Adding the file \"$filename\" to the project."
      set result [$iSrcHelper AddSourceFile "$filename" iconflict]
      OnFail $result {
         if {$result == 6} {
            INFO "The file \"$filename\" is already in the project."
         } else {
            ERR "A problem occurred adding the file \"$filename\" to the project."
         }
      }
   }
}

# Helper to add files to the project and set their origination. 
# Valid origination values are:
#   0 - User
#   1 - Generated
#   2 - Imported
# Files of origination "User" are added through the facilitator, 
# otherwise they are added directly to the File Manager.
proc AddImportedFiles { iProjHelper files origination } {
   switch $origination {
      0 { INFO "Adding User files." }
      1 { INFO "Adding Generated files." }
      2 { INFO "Adding Imported files." }
      default {
         ERR "Invalid parameter: origination was set to \"$origination\", but may only be 0, 1, or 2."
         return 0
      }
   }
   set iFileMgr [ GetFileManager $iProjHelper ]
   if {$iFileMgr == 0} { return 0 }
   foreach filename $files {
      set file_type 0
      set hdl_file 0
      set result [$iFileMgr AddFile "$filename" $file_type hdl_file]
      OnFail $result {
         if {$result == 6} {
            INFO "The file \"$filename\" is already in the project."
         } elseif { $hdl_file == 0 } {
            ERR "A problem occurred adding the file \"$filename\" to the project."
         }
      }
      OnOkPtr hdl_file {
         set ifile [ GetInterface $hdl_file $xilinx::Dpm::IFileID IFile ]
         OnOkPtr ifile {
            set result [ $ifile SetOrigination $origination ]
            if {$result != 1} {
               ERR "A problem occurred setting the origination of \"$filename\" to \"$origination\"."
            }
            Release $ifile
         }
      }
   }
   return 1
}

proc RestoreProjectSettings { iProjHelper project_settings } {
   INFO "Restoring device settings"
   set iScratch [GetScratchPropertyManager $iProjHelper]
   set iPropIter 0
   set iPropSet [ GetInterface $iScratch $xilinx::Dpm::IPropertyNodeSetID IPropertyNodeSet ]
   OnOkPtr iPropSet {
      $iPropSet GetIterator iPropIter
   }
   set index 0
   set lastindex [llength $project_settings]
   ForEachIterEle prop_node $iPropIter {
      set prop_instance 0
      $prop_node GetPropertyInstance prop_instance
      if { $index < $lastindex } {
         set argname [ lindex $project_settings $index ]
         set argvalue [ lindex $project_settings [ expr $index + 1 ] ]
      } else {
         set argname {}
         set argvalue {}
      }
      if { $prop_instance != 0 } {
         set name {}
         $prop_instance GetName name
         if { [string equal $name $argname ] } {
            $prop_instance SetStringValue $argvalue
            incr index
            incr index
         }
      }
      Release $prop_instance
   }
   $iScratch Commit
   # initialize
   $iProjHelper Init
}

#  Helper to load a source control configuration from a stream
#  and then store it back into an ise file.
proc RestoreSourceControlOptions { prjfile istream } {
   INFO "Restoring source control options"
   set config_comp [::Xilinx::Cit::FactoryCreate $::xilinx::Dpm::SourceControlConfigurationCompID ]
   OnOkPtr config_comp { set ipersist [ $config_comp GetInterface $xilinx::Prjrep::IPersistID ] }
   OnOkPtr config_comp { set igetopts [ $config_comp GetInterface $xilinx::Dpm::SrcCtrl::IGetOptionsID ] }
   set helper_comp [::Xilinx::Cit::FactoryCreate $::xilinx::Dpm::SourceControlHelpCompID ]
   OnOkPtr helper_comp { set ihelper [ $config_comp GetInterface $xilinx::Dpm::SrcCtrl::IHelperID ] }
   OnOkPtr ipersist { $ipersist Load istream }
   OnOkPtr ihelper { OnOkPtr igetopts { $ihelper SaveOptions $prjfile $igetopts } }
   Release $helper_comp $config_comp
}

# put a string message in a GUI popup message dialog (if possible),
# Get a user Yes/No response. If the GUI isn't active just 'puts' 
# the message to stdout and return the default value.
#		sMessageGUI - string, the message to display in GUI environment
#		sMessageCmdLine - string, the message to display in CMdLine environment
#		defaultValue - integer, the response to return on a timeout</In>
#		hasCancel - integer, defaulting to 0. If 1, show Yes/No/Cancel buttons</In>
proc dpm_DisplayQuestionDialog { sMessageGUI sMessageCmdLine defaultValue { hasCancel 0} } {
   set iMessageDisplay 0
   if {[catch {
	   set iInterface [Xilinx::CitP::GetInstance $::xilinx::GuiI::IMessageDlgID]
	   set iMessageDisplay [$iInterface GetInterface $::xilinx::GuiI::IMessageDlgID]
   }]} { 
	   # if we cannot get the IMessageDlgID interface then we are most likely
	   # running from command line and not in the GUI.
	   puts $sMessageCmdLine
   } else {
	   # got a good dialog singleton
	   set nTimeout 999999
	   set buttonValue [$iMessageDisplay Question "Project Navigator" $sMessageGUI $hasCancel $nTimeout]
	   if { $buttonValue == 2 } { ; # cancel
		   return 3
	   } elseif { $buttonValue == 3 } { ; # yes
		   return 1
	   } elseif { $buttonValue == 4 } { ; # no
		   return 2
	   } else { # probably timeout
		   return $defaultValue
	   }
   }
   return $defaultValue
}

proc import { {working_area ""} {staging_area ""} { srcctrl_comp 0 } } {
  set project_file "vp2.ise"
  set old_working_dir [pwd]
  # intialize the new project directory (work) and 
  # source control reference directory (staging) to
  # current working directory, when not specified
  if { $working_area == "" } { set working_area [pwd] }
  if { $staging_area == "" } { set staging_area [pwd] }
  set copy_option relative
  set import_files { 
      "6502_sync.vhd" 
      "ClkUnit.sym" 
      "RxFifo.v" 
      "RxFifoBI.v" 
      "RxUnit.sym" 
      "RxUnit.vhd" 
      "TxFifo.v" 
      "TxFifoBI.v" 
      "TxUnit.sym" 
      "TxUnit.vhd" 
      "clkUnit.vhd" 
      "clkUnit38400.vhd" 
      "clockgen.sym" 
      "clockgen.xaw" 
      "clockgen_arwz.ucf" 
      "cpu6502_sync.sym" 
      "cpu_ram.sym" 
      "cpu_ram.v" 
      "cpu_rom.sym" 
      "cpu_rom.v" 
      "ctrlStsRegBI.v" 
      "datamux.sym" 
      "datamux.v" 
      "dda.sym" 
      "dda.v" 
      "dda_bus_if.sym" 
      "dda_bus_if.v" 
      "debounce.sym" 
      "debounce.v" 
      "div_steps.sym" 
      "div_steps.v" 
      "dpMem_dc.v" 
      "eth_rx.sym" 
      "eth_tx.sym" 
      "fifoRTL.v" 
      "gpin_buf.sym" 
      "gpin_buf.v" 
      "gpio_buf.sym" 
      "gpio_buf.v" 
      "gpio_ctrl.sym" 
      "gpio_ctrl.v" 
      "gpout_buf.sym" 
      "gpout_buf.v" 
      "initSD.v" 
      "loader.v" 
      "memory_maped_if.sym" 
      "memory_maped_if.v" 
      "mmu.sym" 
      "mmu.v" 
      "pio.sym" 
      "readWriteSDBlock.v" 
      "readWriteSPIWireData.sym" 
      "readWriteSPIWireData.v" 
      "sdram.sym" 
      "sendCmd.v" 
      "spiCtrl.v" 
      "spiMaster.sym" 
      "spiMaster.v" 
      "spiMaster_defines.v" 
      "spiTxRxData.v" 
      "spi_buf_ctrl.v" 
      "spi_master_ctrl.sym" 
      "spi_master_ctrl.v" 
      "spi_slave.sym" 
      "spi_slave.v" 
      "step_gen.sym" 
      "step_gen.v" 
      "stepper_ctrl.sch" 
      "steppers_module.sch" 
      "steppers_module.sym" 
      "test_debounce.v" 
      "test_div_steps.v" 
      "test_mmi.v" 
      "test_spi_wire.v" 
      "test_step_gen.v" 
      "test_stepper_ctrl.v" 
      "test_steppers_module.v" 
      "test_top.v" 
      "timescale.v" 
      "top.sch" 
      "top.sym" 
      "top.ucf" 
      "uart_lib.vhd" 
      "wishBoneBI.v"}
  INFO "Copying files from \"$staging_area\" to \"$working_area\""
  # Must be in the staging directory before calling CopyIn.
  cd [file normalize "$staging_area"]
  foreach file $import_files {
     CopyIn "$file" "$working_area" $copy_option
  }
  set iProjHelper 0
   # Bail if a project currently open.
   if {[IsProjectOpen]} {
      ERR "The project must be closed before performing this operation."
      return 0
   }
   # Must be in the working area (i.e. project directory) before calling recreating the project.
   cd [file normalize "$working_area"]
   INFO "Recreating project \"$project_file\"."
   HandleException {
      set iProjHelper [ OpenFacilProject "$project_file"]
   } "A problem occurred while creating the project \"$project_file\"."
   if {$iProjHelper == 0} {
      cd "$old_working_dir"
      return 0
   }
  set project_settings { 
     "PROP_DevFamily" "Virtex2P"
     "PROP_DevDevice" "xc2vp50"
     "PROP_DevPackage" "ff1152"
     "PROP_DevSpeed" "-6"
     "PROP_Top_Level_Module_Type" "Schematic"
     "PROP_Synthesis_Tool" "XST (VHDL/Verilog)"
     "PROP_Simulator" "ISE Simulator (VHDL/Verilog)"
     "PROP_PreferredLanguage" "Verilog"
     "PROP_Enable_Message_Capture" "true"
     "PROP_Enable_Message_Filtering" "false"
     "PROP_Enable_Incremental_Messaging" "false"
     }

  HandleException {
    RestoreProjectSettings $iProjHelper $project_settings 
  } "A problem occured while restoring project settings."

  set user_files { 
      "6502_sync.vhd" 
      "RxFifo.v" 
      "RxFifoBI.v" 
      "RxUnit.vhd" 
      "TxFifo.v" 
      "TxFifoBI.v" 
      "TxUnit.vhd" 
      "clkUnit.vhd" 
      "clkUnit38400.vhd" 
      "clockgen.xaw" 
      "cpu_ram.v" 
      "cpu_rom.v" 
      "ctrlStsRegBI.v" 
      "datamux.v" 
      "dda.v" 
      "dda_bus_if.v" 
      "debounce.v" 
      "div_steps.v" 
      "dpMem_dc.v" 
      "fifoRTL.v" 
      "gpin_buf.v" 
      "gpio_buf.v" 
      "gpio_ctrl.v" 
      "gpout_buf.v" 
      "initSD.v" 
      "loader.v" 
      "memory_maped_if.v" 
      "mmu.v" 
      "readWriteSDBlock.v" 
      "readWriteSPIWireData.v" 
      "sendCmd.v" 
      "spiCtrl.v" 
      "spiMaster.v" 
      "spiMaster_defines.v" 
      "spiTxRxData.v" 
      "spi_buf_ctrl.v" 
      "spi_master_ctrl.v" 
      "spi_slave.v" 
      "step_gen.v" 
      "stepper_ctrl.sch" 
      "steppers_module.sch" 
      "test_debounce.v" 
      "test_div_steps.v" 
      "test_mmi.v" 
      "test_spi_wire.v" 
      "test_step_gen.v" 
      "test_stepper_ctrl.v" 
      "test_steppers_module.v" 
      "test_top.v" 
      "timescale.v" 
      "top.sch" 
      "top.ucf" 
      "uart_lib.vhd" 
      "wishBoneBI.v"}

  HandleException {
    AddUserFiles $iProjHelper $user_files
  } "A problem occured while restoring user files."

  set imported_files { 
      "ClkUnit.sym" 
      "RxUnit.sym" 
      "TxUnit.sym" 
      "clockgen.sym" 
      "clockgen_arwz.ucf" 
      "cpu6502_sync.sym" 
      "cpu_ram.sym" 
      "cpu_rom.sym" 
      "datamux.sym" 
      "dda.sym" 
      "dda_bus_if.sym" 
      "debounce.sym" 
      "div_steps.sym" 
      "eth_rx.sym" 
      "eth_tx.sym" 
      "gpin_buf.sym" 
      "gpio_buf.sym" 
      "gpio_ctrl.sym" 
      "gpout_buf.sym" 
      "memory_maped_if.sym" 
      "mmu.sym" 
      "pio.sym" 
      "readWriteSPIWireData.sym" 
      "sdram.sym" 
      "spiMaster.sym" 
      "spi_master_ctrl.sym" 
      "spi_slave.sym" 
      "step_gen.sym" 
      "steppers_module.sym" 
      "top.sym"}

  set origination 2

  HandleException {
    AddImportedFiles $iProjHelper $imported_files $origination
  } "A problem occured while restoring imported files."

  set process_props { 
      "A" "" "" "" "PROPEXT_SynthMultStyle_virtex2" "Auto" 
      "A" "" "" "" "PROPEXT_xilxBitgCfg_DCIUpdateMode_virtex2p" "As Required" 
      "A" "" "" "" "PROPEXT_xilxBitgCfg_TDO_virtex2p" "Float" 
      "A" "" "" "" "PROPEXT_xilxBitgStart_Clk_Done_virtex2p" "Default (4)" 
      "A" "" "" "" "PROPEXT_xilxMapGenInputK_virtex2" "4" 
      "A" "" "" "" "PROPEXT_xilxSynthAddBufg_virtex2" "16" 
      "A" "" "" "" "PROPEXT_xilxSynthMaxFanout_virtex2" "500" 
      "A" "" "" "" "PROP_AutoGenFile" "false" 
      "A" "" "" "" "PROP_BehavioralSimTop" "Module|stepper_ctrl_stepper_ctrl_sch_tb" 
      "A" "" "" "" "PROP_CPLDFitkeepio" "false" 
      "A" "" "" "" "PROP_CompxlibAbelLib" "true" 
      "A" "" "" "" "PROP_CompxlibCPLDDetLib" "true" 
      "A" "" "" "" "PROP_CompxlibOtherCompxlibOpts" "" 
      "A" "" "" "" "PROP_CompxlibOutputDir" "$XILINX/<language>/<simulator>" 
      "A" "" "" "" "PROP_CompxlibOverwriteLib" "Overwrite" 
      "A" "" "" "" "PROP_CompxlibSimPrimatives" "true" 
      "A" "" "" "" "PROP_CompxlibXlnxCoreLib" "true" 
      "A" "" "" "" "PROP_ConstFileAddOption" "true" 
      "A" "" "" "" "PROP_ConstFileName" "" 
      "A" "" "" "" "PROP_CorgenRegenCore" "Under Current Project Setting" 
      "A" "" "" "" "PROP_CurrentFloorplanFile" "" 
      "A" "" "" "" "PROP_DefaultTBName" "Default" 
      "A" "" "" "" "PROP_DesignName" "vp2" 
      "A" "" "" "" "PROP_Dummy" "dum1" 
      "A" "" "" "" "PROP_EnableWYSIWYG" "None" 
      "A" "" "" "" "PROP_Enable_Incremental_Messaging" "false" 
      "A" "" "" "" "PROP_Enable_Message_Capture" "true" 
      "A" "" "" "" "PROP_Enable_Message_Filtering" "false" 
      "A" "" "" "" "PROP_FitterReportFormat" "HTML" 
      "A" "" "" "" "PROP_FlowDebugLevel" "0" 
      "A" "" "" "" "PROP_FunctionBlockInputLimit" "38" 
      "A" "" "" "" "PROP_HierarchicalProjectType" "N/A" 
      "A" "" "" "" "PROP_ISimLibSearchOrderFile" "" 
      "A" "" "" "" "PROP_ISimOtherCompilerOptions_behav" "" 
      "A" "" "" "" "PROP_ISimOtherCompilerOptions_fit" "" 
      "A" "" "" "" "PROP_ISimOtherCompilerOptions_par" "" 
      "A" "" "" "" "PROP_ISimSDFTimingToBeRead" "Setup Time" 
      "A" "" "" "" "PROP_ISimSpecifyDefMacroAndValueChkSyntax" "" 
      "A" "" "" "" "PROP_ISimSpecifySearchDirectoryChkSyntax" "" 
      "A" "" "" "" "PROP_ISimUseCustomCompilationOrder" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_behav_tb" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_behav_tbw" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_gen_tbw" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_launch" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_par_tb" "false" 
      "A" "" "" "" "PROP_ISimUseCustomSimCmdFile_par_tbw" "false" 
      "A" "" "" "" "PROP_ISimUutInstName" "UUT" 
      "A" "" "" "" "PROP_ImpactProjectFile" "Default" 
      "A" "" "" "" "PROP_LastAppliedGoal" "Balanced" 
      "A" "" "" "" "PROP_LastAppliedStrategy" "Xilinx Default (unlocked)" 
      "A" "" "" "" "PROP_LastUnlockStatus" "false" 
      "A" "" "" "" "PROP_LoadPostTrceTSIFile" "false" 
      "A" "" "" "" "PROP_MSimSDFTimingToBeRead" "Setup Time" 
      "A" "" "" "" "PROP_MapGlobalOptimization" "false" 
      "A" "" "" "" "PROP_ModelSimUseConfigName" "false" 
      "A" "" "" "" "PROP_OverwriteSym" "false" 
      "A" "" "" "" "PROP_Parse_Edif_Module" "false" 
      "A" "" "" "" "PROP_Parse_Target" "synthesis" 
      "A" "" "" "" "PROP_PartitionCreateDelete" "" 
      "A" "" "" "" "PROP_PartitionForcePlacement" "" 
      "A" "" "" "" "PROP_PartitionForceSynth" "" 
      "A" "" "" "" "PROP_PartitionForceTranslate" "" 
      "A" "" "" "" "PROP_PlsClockEnable" "true" 
      "A" "" "" "" "PROP_PostFitSimTop" "" 
      "A" "" "" "" "PROP_PostMapSimTop" "Module|test_step_gen" 
      "A" "" "" "" "PROP_PostParSimTop" "Module|test_div_steps" 
      "A" "" "" "" "PROP_PostSynthSimTop" "Module|test_step_gen" 
      "A" "" "" "" "PROP_PostTrceFastPath" "false" 
      "A" "" "" "" "PROP_PostTrceGenDatasheet" "true" 
      "A" "" "" "" "PROP_PostTrceGenTimegroups" "false" 
      "A" "" "" "" "PROP_PostXlateSimTop" "Module|test_step_gen" 
      "A" "" "" "" "PROP_PreTrceFastPath" "false" 
      "A" "" "" "" "PROP_PreTrceGenDatasheet" "true" 
      "A" "" "" "" "PROP_PreTrceGenTimegroups" "false" 
      "A" "" "" "" "PROP_PreTrceTSIFile" "" 
      "A" "" "" "" "PROP_PrecAddIOPads" "true" 
      "A" "" "" "" "PROP_PrecAdvFsmOptimization" "true" 
      "A" "" "" "" "PROP_PrecArrayBoundsCheck" "false" 
      "A" "" "" "" "PROP_PrecCreateUcfFromRtlConstraints" "false" 
      "A" "" "" "" "PROP_PrecEdif" "true" 
      "A" "" "" "" "PROP_PrecFsmEncoding" "Auto" 
      "A" "" "" "" "PROP_PrecFullCase" "false" 
      "A" "" "" "" "PROP_PrecInputSdcFile" "" 
      "A" "" "" "" "PROP_PrecOutputFileBase" "" 
      "A" "" "" "" "PROP_PrecParallelCase" "false" 
      "A" "" "" "" "PROP_PrecResourceSharing" "true" 
      "A" "" "" "" "PROP_PrecRptCriticalPaths" "true" 
      "A" "" "" "" "PROP_PrecRptMissingConstraints" "false" 
      "A" "" "" "" "PROP_PrecRptTimingSummary" "true" 
      "A" "" "" "" "PROP_PrecRptTimingViolations" "true" 
      "A" "" "" "" "PROP_PrecRptclockFreq" "true" 
      "A" "" "" "" "PROP_PrecRunRetiming" "false" 
      "A" "" "" "" "PROP_PrecShowClockDomainCrossing" "false" 
      "A" "" "" "" "PROP_PrecShowNetFanOut" "true" 
      "A" "" "" "" "PROP_PrecTranSetResetToLatches" "true" 
      "A" "" "" "" "PROP_PrecUseSafeFsm" "false" 
      "A" "" "" "" "PROP_PrecVerilog" "false" 
      "A" "" "" "" "PROP_PrecVhdl" "false" 
      "A" "" "" "" "PROP_PrecVhdlSyntax" "VHDL 93" 
      "A" "" "" "" "PROP_ProjectGeneratorType" "ProjNav" 
      "A" "" "" "" "PROP_SimDo" "true" 
      "A" "" "" "" "PROP_SimModelGenerateTestbenchFile" "false" 
      "A" "" "" "" "PROP_SimModelInsertBuffersPulseSwallow" "false" 
      "A" "" "" "" "PROP_SimModelOtherNetgenOpts" "" 
      "A" "" "" "" "PROP_SimModelRetainHierarchy" "true" 
      "A" "" "" "" "PROP_SimUseCustom_behav" "false" 
      "A" "" "" "" "PROP_SimUseCustom_launchMSim" "false" 
      "A" "" "" "" "PROP_SimUseCustom_postMap" "false" 
      "A" "" "" "" "PROP_SimUseCustom_postPar" "false" 
      "A" "" "" "" "PROP_SimUseCustom_postXlate" "false" 
      "A" "" "" "" "PROP_SimUserCompileList_launchMSim" "" 
      "A" "" "" "" "PROP_StartImpView" "" 
      "A" "" "" "" "PROP_StopImpView" "AbstractSynthesis" 
      "A" "" "" "" "PROP_SynthCaseImplStyle" "None" 
      "A" "" "" "" "PROP_SynthDecoderExtract" "true" 
      "A" "" "" "" "PROP_SynthDisableIOInsertion" "false" 
      "A" "" "" "" "PROP_SynthEncoderExtract" "Yes" 
      "A" "" "" "" "PROP_SynthEnumEncoding" "default" 
      "A" "" "" "" "PROP_SynthExtractMux" "Yes" 
      "A" "" "" "" "PROP_SynthExtractRAM" "true" 
      "A" "" "" "" "PROP_SynthExtractROM" "true" 
      "A" "" "" "" "PROP_SynthFanout" "100" 
      "A" "" "" "" "PROP_SynthFsmEncode" "Auto" 
      "A" "" "" "" "PROP_SynthLogicalShifterExtract" "true" 
      "A" "" "" "" "PROP_SynthModular" "false" 
      "A" "" "" "" "PROP_SynthNumCriticalPaths" "0" 
      "A" "" "" "" "PROP_SynthNumStartEndPoints" "0" 
      "A" "" "" "" "PROP_SynthOpt" "Speed" 
      "A" "" "" "" "PROP_SynthOptEffort" "Normal" 
      "A" "" "" "" "PROP_SynthPipelining" "true" 
      "A" "" "" "" "PROP_SynthProcBound" "true" 
      "A" "" "" "" "PROP_SynthResSharing" "true" 
      "A" "" "" "" "PROP_SynthResourceSharing" "true" 
      "A" "" "" "" "PROP_SynthRetiming" "false" 
      "A" "" "" "" "PROP_SynthShiftRegExtract" "true" 
      "A" "" "" "" "PROP_SynthSymbolicFsm" "true" 
      "A" "" "" "" "PROP_SynthTop" "Module|top" 
      "A" "" "" "" "PROP_SynthUseFsmExplorerData" "false" 
      "A" "" "" "" "PROP_SynthXORCollapse" "true" 
      "A" "" "" "" "PROP_ToolPathChipscope" "" 
      "A" "" "" "" "PROP_ToolPathLeonardoSpectrum" "" 
      "A" "" "" "" "PROP_ToolPathModelSim" "" 
      "A" "" "" "" "PROP_ToolPathPrecision" "" 
      "A" "" "" "" "PROP_ToolPathSynplify" "" 
      "A" "" "" "" "PROP_ToolPathSynplifyPro" "" 
      "A" "" "" "" "PROP_Top_Level_Module_Type" "Schematic" 
      "A" "" "" "" "PROP_UseDataGate" "true" 
      "A" "" "" "" "PROP_UseSmartGuide" "false" 
      "A" "" "" "" "PROP_UserBrowsedStrategyFiles" "" 
      "A" "" "" "" "PROP_UserConstraintEditorPreference" "Constraints Editor" 
      "A" "" "" "" "PROP_UserEditorCustomSetting" "" 
      "A" "" "" "" "PROP_UserEditorPreference" "ISE Text Editor" 
      "A" "" "" "" "PROP_Verilog2001" "true" 
      "A" "" "" "" "PROP_VirtexSynthAutoConstrain" "true" 
      "A" "" "" "" "PROP_WriteVHDLNetlist" "false" 
      "A" "" "" "" "PROP_WriteVendorConstFile" "true" 
      "A" "" "" "" "PROP_WriteVerilogNetlist" "false" 
      "A" "" "" "" "PROP_XPORTInpFileName" "" 
      "A" "" "" "" "PROP_XPORTInpFileType" "ABEL" 
      "A" "" "" "" "PROP_XPORTOutFileType" "VHDL" 
      "A" "" "" "" "PROP_XPORTlistInpFiles" "false" 
      "A" "" "" "" "PROP_XPowerOptInputTclScript" "" 
      "A" "" "" "" "PROP_XPowerOptLoadPCFFile" "Default" 
      "A" "" "" "" "PROP_XPowerOptLoadVCDFile" "Default" 
      "A" "" "" "" "PROP_XPowerOptLoadXMLFile" "Default" 
      "A" "" "" "" "PROP_XPowerOptOutputFile" "Default" 
      "A" "" "" "" "PROP_XPowerOptVerboseRpt" "false" 
      "A" "" "" "" "PROP_XPowerOtherXPowerOpts" "" 
      "A" "" "" "" "PROP_XplorerMode" "Off" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq0" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq1" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq2" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq3" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq4" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_keySeq5" "None" 
      "A" "" "" "" "PROP_bitgen_Encrypt_startCBC" "" 
      "A" "" "" "" "PROP_bitgen_Encrypt_startKey" "None" 
      "A" "" "" "" "PROP_bitgen_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_cpldBestFit" "false" 
      "A" "" "" "" "PROP_cpldfitHDLeqStyle" "Source" 
      "A" "" "" "" "PROP_cpldfit_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_fitGenSimModel" "false" 
      "A" "" "" "" "PROP_hprep6_autosig" "false" 
      "A" "" "" "" "PROP_hprep6_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_ibiswriterEnableMultiLingualModel" "false" 
      "A" "" "" "" "PROP_ibiswriterGeneratePackageParasitics" "false" 
      "A" "" "" "" "PROP_ibiswriterShowAllModels" "false" 
      "A" "" "" "" "PROP_isimCompileForHdlDebug" "true" 
      "A" "" "" "" "PROP_isimIncreCompilation" "true" 
      "A" "" "" "" "PROP_isimSpecifyDefMacroAndValue" "" 
      "A" "" "" "" "PROP_isimSpecifySearchDirectory" "" 
      "A" "" "" "" "PROP_isimValueRangeCheck" "false" 
      "A" "" "" "" "PROP_lockPinsUcfFile" "" 
      "A" "" "" "" "PROP_mapIgnoreTimingConstraints" "false" 
      "A" "" "" "" "PROP_mapTimingAnalyzerLoadDesign" "true" 
      "A" "" "" "" "PROP_mapUseRLOCConstraints" "true" 
      "A" "" "" "" "PROP_map_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_mpprRsltToCopy" "" 
      "A" "" "" "" "PROP_mpprViewPadRptsForAllRslt" "true" 
      "A" "" "" "" "PROP_mpprViewParRptsForAllRslt" "true" 
      "A" "" "" "" "PROP_ngdbuildUseLOCConstraints" "true" 
      "A" "" "" "" "PROP_ngdbuild_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_parIgnoreTimingConstraints" "false" 
      "A" "" "" "" "PROP_parTimingAnalyzerLoadDesign" "true" 
      "A" "" "" "" "PROP_parUseTimingConstraints" "true" 
      "A" "" "" "" "PROP_par_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_primeCorrelateOutput" "false" 
      "A" "" "" "" "PROP_primeFlatternOutputNetlist" "false" 
      "A" "" "" "" "PROP_primeTopLevelModule" "" 
      "A" "" "" "" "PROP_primetimeBlockRamData" "" 
      "A" "" "" "" "PROP_taengine_otherCmdLineOptions" "" 
      "A" "" "" "" "PROP_xcpldFitDesInit" "Low" 
      "A" "" "" "" "PROP_xcpldFitDesInputLmt_xbr" "32" 
      "A" "" "" "" "PROP_xcpldFitDesMultiLogicOpt" "true" 
      "A" "" "" "" "PROP_xcpldFitDesSlew" "Fast" 
      "A" "" "" "" "PROP_xcpldFitDesTimingCst" "true" 
      "A" "" "" "" "PROP_xcpldFitDesTriMode" "Keeper" 
      "A" "" "" "" "PROP_xcpldFitDesUnused" "Keeper" 
      "A" "" "" "" "PROP_xcpldFitDesVolt" "LVCMOS18" 
      "A" "" "" "" "PROP_xcpldFitTemplate_xpla3" "Optimize Density" 
      "A" "" "" "" "PROP_xcpldFittimRptOption" "Summary" 
      "A" "" "" "" "PROP_xcpldUseGlobalClocks" "true" 
      "A" "" "" "" "PROP_xcpldUseGlobalOutputEnables" "true" 
      "A" "" "" "" "PROP_xcpldUseGlobalSetReset" "true" 
      "A" "" "" "" "PROP_xcpldUseLocConst" "Always" 
      "A" "" "" "" "PROP_xilxBitgCfg_Clk" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_Code" "0xFFFFFFFF" 
      "A" "" "" "" "PROP_xilxBitgCfg_DCMBandgap" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_DCMShutdown" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_Done" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_ASCIIFile" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_BinaryFile" "true" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_BitFile" "true" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_Compress" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_DRC" "true" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_EnableCRC" "true" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_GClkDel0" "11111" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_GClkDel1" "11111" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_GClkDel2" "11111" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_GClkDel3" "11111" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_IEEE1532File" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_IEEE1532File_xbr" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_GenOpt_ReadBack" "false" 
      "A" "" "" "" "PROP_xilxBitgCfg_M0" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_M1" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_M2" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_Pgm" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_PwrDown" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_Rate" "4" 
      "A" "" "" "" "PROP_xilxBitgCfg_TCK" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_TDI" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_TMS" "Pull Up" 
      "A" "" "" "" "PROP_xilxBitgCfg_Unused" "Float" 
      "A" "" "" "" "PROP_xilxBitgReadBk_Sec" "Enable Readback and Reconfiguration" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk" "CCLK" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_DriveDone" "false" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_EnOut" "Default (5)" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_MatchCycle" "Auto" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_RelDLL" "Default (NoWait)" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_RelSet" "Default (6)" 
      "A" "" "" "" "PROP_xilxBitgStart_Clk_WrtEn" "Default (6)" 
      "A" "" "" "" "PROP_xilxBitgStart_IntDone" "false" 
      "A" "" "" "" "PROP_xilxMapAllowLogicOpt" "false" 
      "A" "" "" "" "PROP_xilxMapCoverMode" "Area" 
      "A" "" "" "" "PROP_xilxMapDisableRegOrdering" "false" 
      "A" "" "" "" "PROP_xilxMapPackRegInto" "Off" 
      "A" "" "" "" "PROP_xilxMapReplicateLogic" "true" 
      "A" "" "" "" "PROP_xilxMapReportDetail" "false" 
      "A" "" "" "" "PROP_xilxMapSliceLogicInUnusedBRAMs" "false" 
      "A" "" "" "" "PROP_xilxMapTimingDrivenPacking" "false" 
      "A" "" "" "" "PROP_xilxMapTrimUnconnSig" "true" 
      "A" "" "" "" "PROP_xilxNgdbldIOPads" "false" 
      "A" "" "" "" "PROP_xilxNgdbldMacro" "" 
      "A" "" "" "" "PROP_xilxNgdbldNTType" "Timestamp" 
      "A" "" "" "" "PROP_xilxNgdbldUR" "" 
      "A" "" "" "" "PROP_xilxNgdbldUnexpBlks" "false" 
      "A" "" "" "" "PROP_xilxNgdbld_AUL" "false" 
      "A" "" "" "" "PROP_xilxPARplacerCostTable" "1" 
      "A" "" "" "" "PROP_xilxPARplacerEffortLevel" "None" 
      "A" "" "" "" "PROP_xilxPARrouterEffortLevel" "None" 
      "A" "" "" "" "PROP_xilxPARstrat" "Normal Place and Route" 
      "A" "" "" "" "PROP_xilxPARuseBondedIO" "false" 
      "A" "" "" "" "PROP_xilxPostTrceAdvAna" "false" 
      "A" "" "" "" "PROP_xilxPostTrceEndpointPath" "" 
      "A" "" "" "" "PROP_xilxPostTrceRpt" "Verbose Report" 
      "A" "" "" "" "PROP_xilxPostTrceRptLimit" "3" 
      "A" "" "" "" "PROP_xilxPostTrceStamp" "" 
      "A" "" "" "" "PROP_xilxPostTrceTSIFile" "" 
      "A" "" "" "" "PROP_xilxPostTrceUncovPath" "" 
      "A" "" "" "" "PROP_xilxPreTrceAdvAna" "false" 
      "A" "" "" "" "PROP_xilxPreTrceEndpointPath" "" 
      "A" "" "" "" "PROP_xilxPreTrceRpt" "Verbose Report" 
      "A" "" "" "" "PROP_xilxPreTrceRptLimit" "3" 
      "A" "" "" "" "PROP_xilxPreTrceUncovPath" "" 
      "A" "" "" "" "PROP_xilxSynthAddIObuf" "true" 
      "A" "" "" "" "PROP_xilxSynthGlobOpt" "AllClockNets" 
      "A" "" "" "" "PROP_xilxSynthKeepHierarchy" "No" 
      "A" "" "" "" "PROP_xilxSynthKeepHierarchy_CPLD" "Yes" 
      "A" "" "" "" "PROP_xilxSynthMacroPreserve" "true" 
      "A" "" "" "" "PROP_xilxSynthRegBalancing" "No" 
      "A" "" "" "" "PROP_xilxSynthRegDuplication" "true" 
      "A" "" "" "" "PROP_xilxSynthXORPreserve" "true" 
      "A" "" "" "" "PROP_xilxTriStateBuffTXMode" "Off" 
      "A" "" "" "" "PROP_xstAsynToSync" "false" 
      "A" "" "" "" "PROP_xstAutoBRAMPacking" "false" 
      "A" "" "" "" "PROP_xstBRAMUtilRatio" "100" 
      "A" "" "" "" "PROP_xstBusDelimiter" "<>" 
      "A" "" "" "" "PROP_xstCase" "Maintain" 
      "A" "" "" "" "PROP_xstCoresSearchDir" "" 
      "A" "" "" "" "PROP_xstCrossClockAnalysis" "false" 
      "A" "" "" "" "PROP_xstEquivRegRemoval" "true" 
      "A" "" "" "" "PROP_xstFsmStyle" "LUT" 
      "A" "" "" "" "PROP_xstGenerateRTLNetlist" "Yes" 
      "A" "" "" "" "PROP_xstGenericsParameters" "" 
      "A" "" "" "" "PROP_xstHierarchySeparator" "/" 
      "A" "" "" "" "PROP_xstIniFile" "" 
      "A" "" "" "" "PROP_xstLibSearchOrder" "" 
      "A" "" "" "" "PROP_xstNetlistHierarchy" "As Optimized" 
      "A" "" "" "" "PROP_xstOptimizeInsPrimtives" "false" 
      "A" "" "" "" "PROP_xstPackIORegister" "Auto" 
      "A" "" "" "" "PROP_xstReadCores" "true" 
      "A" "" "" "" "PROP_xstSlicePacking" "true" 
      "A" "" "" "" "PROP_xstSliceUtilRatio" "100" 
      "A" "" "" "" "PROP_xstTristate2Logic" "Yes" 
      "A" "" "" "" "PROP_xstUseClockEnable" "Yes" 
      "A" "" "" "" "PROP_xstUseSyncReset" "Yes" 
      "A" "" "" "" "PROP_xstUseSyncSet" "Yes" 
      "A" "" "" "" "PROP_xstUseSynthConstFile" "true" 
      "A" "" "" "" "PROP_xstUserCompileList" "" 
      "A" "" "" "" "PROP_xstVeriIncludeDir_Global" "" 
      "A" "" "" "" "PROP_xstVerilog2001" "true" 
      "A" "" "" "" "PROP_xstVerilogMacros" "" 
      "A" "" "" "" "PROP_xstWorkDir" "./xst" 
      "A" "" "" "" "PROP_xstWriteTimingConstraints" "false" 
      "A" "" "" "" "PROP_xst_otherCmdLineOptions" "" 
      "A" "" "" "PROP_SteCreatedBy" "PROP_SteCreatedBy" "" 
      "A" "AutoGeneratedView" "VIEW_AnnotatedPreSimulation" "" "PROP_ISimIncreCompilation" "true" 
      "A" "AutoGeneratedView" "VIEW_AnnotatedPreSimulation" "" "PROP_ISimSpecifyDefMacroAndValue" "" 
      "A" "AutoGeneratedView" "VIEW_AnnotatedPreSimulation" "" "PROP_ISimSpecifySearchDirectory" "" 
      "A" "AutoGeneratedView" "VIEW_AnnotatedPreSimulation" "" "PROP_ISimValueRangeCheck" "false" 
      "A" "AutoGeneratedView" "VIEW_AnnotatedPreSimulation" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_BehavioralFuse" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_Post-ParFuse" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_ISimCompileForHdlDebug" "true" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_ISimIncreCompilation" "true" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_ISimSpecifyDefMacroAndValue" "" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_ISimSpecifySearchDirectory" "" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_ISimValueRangeCheck" "false" 
      "A" "AutoGeneratedView" "VIEW_Post-ParPreSimulation" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_PostAbstractSimulation" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimCompileForHdlDebug" "true" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimIncreCompilation" "true" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimSpecifyDefMacroAndValue" "" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimSpecifySearchDir" "" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimSpecifySearchDirectory" "" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_ISimValueRangeCheck" "false" 
      "A" "AutoGeneratedView" "VIEW_PreSimulation" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_TBWPost-ParPreSimulation" "" "PROP_ISimCompileForHdlDebug" "true" 
      "A" "AutoGeneratedView" "VIEW_TBWPost-ParPreSimulation" "" "PROP_ISimIncreCompilation" "true" 
      "A" "AutoGeneratedView" "VIEW_TBWPost-ParPreSimulation" "" "PROP_ISimSpecifyDefMacroAndValue" "" 
      "A" "AutoGeneratedView" "VIEW_TBWPost-ParPreSimulation" "" "PROP_ISimSpecifySearchDirectory" "" 
      "A" "AutoGeneratedView" "VIEW_TBWPost-ParPreSimulation" "" "PROP_ISimValueRangeCheck" "false" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_ISimCompileForHdlDebug" "true" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_ISimIncreCompilation" "true" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_ISimSpecifyDefMacroAndValue" "" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_ISimSpecifySearchDirectory" "" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_ISimValueRangeCheck" "false" 
      "A" "AutoGeneratedView" "VIEW_TBWPreSimulation" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_XSTPreSynthesis" "" "PROP_TopDesignUnit" "" 
      "A" "AutoGeneratedView" "VIEW_XSTPreSynthesis" "" "PROP_xstVeriIncludeDir" "" 
      "B" "" "" "" "PROPEXT_SynthFrequencySyn_virtex" "0.0" 
      "B" "" "" "" "PROP_AceActiveName" "" 
      "B" "" "" "" "PROP_DevFamily" "Virtex2P" 
      "B" "" "" "" "PROP_FitterOptimization_xpla3" "Density" 
      "B" "" "" "" "PROP_ISimCustomCompilationOrderFile" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_behav_tb" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_behav_tbw" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_gen_tbw" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_launch" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_par_tb" "" 
      "B" "" "" "" "PROP_ISimCustomSimCmdFileName_par_tbw" "" 
      "B" "" "" "" "PROP_ISimGenVCDFile_par_tb" "false" 
      "B" "" "" "" "PROP_ISimGenVCDFile_par_tbw" "false" 
      "B" "" "" "" "PROP_ISimSimulationRun_behav_tb" "true" 
      "B" "" "" "" "PROP_ISimSimulationRun_behav_tbw" "true" 
      "B" "" "" "" "PROP_ISimSimulationRun_par_tb" "true" 
      "B" "" "" "" "PROP_ISimSimulationRun_par_tbw" "true" 
      "B" "" "" "" "PROP_ISimStoreAllSignalTransitions_behav_tb" "false" 
      "B" "" "" "" "PROP_ISimStoreAllSignalTransitions_behav_tbw" "false" 
      "B" "" "" "" "PROP_ISimStoreAllSignalTransitions_par_tb" "false" 
      "B" "" "" "" "PROP_ISimStoreAllSignalTransitions_par_tbw" "false" 
      "B" "" "" "" "PROP_MapEffortLevel" "Medium" 
      "B" "" "" "" "PROP_MapEquivalentRegisterRemoval" "true" 
      "B" "" "" "" "PROP_MapLogicOptimization" "false" 
      "B" "" "" "" "PROP_MapPlacerCostTable" "1" 
      "B" "" "" "" "PROP_MapPowerReduction" "false" 
      "B" "" "" "" "PROP_MapRegDuplication" "false" 
      "B" "" "" "" "PROP_MapRetiming" "false" 
      "B" "" "" "" "PROP_ModelSimConfigName" "Default" 
      "B" "" "" "" "PROP_ModelSimDataWin" "false" 
      "B" "" "" "" "PROP_ModelSimListWin" "false" 
      "B" "" "" "" "PROP_ModelSimProcWin" "false" 
      "B" "" "" "" "PROP_ModelSimSignalWin" "true" 
      "B" "" "" "" "PROP_ModelSimSimRes" "Default (1 ps)" 
      "B" "" "" "" "PROP_ModelSimSimRunTime_tb" "1000ns" 
      "B" "" "" "" "PROP_ModelSimSimRunTime_tbw" "1000ns" 
      "B" "" "" "" "PROP_ModelSimSourceWin" "false" 
      "B" "" "" "" "PROP_ModelSimStructWin" "true" 
      "B" "" "" "" "PROP_ModelSimUutInstName_postFit" "UUT" 
      "B" "" "" "" "PROP_ModelSimUutInstName_postMap" "UUT" 
      "B" "" "" "" "PROP_ModelSimUutInstName_postPar" "UUT" 
      "B" "" "" "" "PROP_ModelSimVarsWin" "false" 
      "B" "" "" "" "PROP_ModelSimWaveWin" "true" 
      "B" "" "" "" "PROP_PrecNumOfCriticalPaths" "1" 
      "B" "" "" "" "PROP_PrecNumOfSumPaths" "10" 
      "B" "" "" "" "PROP_SimCustom_behav" "" 
      "B" "" "" "" "PROP_SimCustom_launchMSim" "" 
      "B" "" "" "" "PROP_SimCustom_postMap" "" 
      "B" "" "" "" "PROP_SimCustom_postPar" "" 
      "B" "" "" "" "PROP_SimCustom_postXlate" "" 
      "B" "" "" "" "PROP_SimGenVcdFile" "false" 
      "B" "" "" "" "PROP_SimModelRenTopLevInstTo" "UUT" 
      "B" "" "" "" "PROP_SimSyntax" "93" 
      "B" "" "" "" "PROP_SimUseExpDeclOnly" "true" 
      "B" "" "" "" "PROP_SimUserCompileList_behav" "" 
      "B" "" "" "" "PROP_Simulator" "ISE Simulator (VHDL/Verilog)" 
      "B" "" "" "" "PROP_SmartGuideFileName" "top_guide.ncd" 
      "B" "" "" "" "PROP_SynthConstraintsFile" "" 
      "B" "" "" "" "PROP_SynthMuxStyle" "Auto" 
      "B" "" "" "" "PROP_SynthRAMStyle" "Auto" 
      "B" "" "" "" "PROP_XPowerOptAdvancedVerboseRpt" "false" 
      "B" "" "" "" "PROP_XPowerOptMaxNumberLines" "1000" 
      "B" "" "" "" "PROP_XplorerEnableRetiming" "true" 
      "B" "" "" "" "PROP_XplorerNumIterations" "7" 
      "B" "" "" "" "PROP_XplorerOtherCmdLineOptions" "" 
      "B" "" "" "" "PROP_XplorerRunType" "Yes" 
      "B" "" "" "" "PROP_XplorerWarnToBackup" "true" 
      "B" "" "" "" "PROP_bitgen_Encrypt_Encrypt" "false" 
      "B" "" "" "" "PROP_impactBaud" "None" 
      "B" "" "" "" "PROP_impactConfigFileName" "" 
      "B" "" "" "" "PROP_impactConfigMode" "None" 
      "B" "" "" "" "PROP_impactPort" "Auto - default" 
      "B" "" "" "" "PROP_mapTimingMode" "Non Timing Driven" 
      "B" "" "" "" "PROP_mpprViewPadRptForSelRslt" "" 
      "B" "" "" "" "PROP_mpprViewParRptForSelRslt" "" 
      "B" "" "" "" "PROP_parGenAsyDlyRpt" "false" 
      "B" "" "" "" "PROP_parGenClkRegionRpt" "false" 
      "B" "" "" "" "PROP_parGenSimModel" "false" 
      "B" "" "" "" "PROP_parGenTimingRpt" "true" 
      "B" "" "" "" "PROP_parMpprNodelistFile" "" 
      "B" "" "" "" "PROP_parMpprParIterations" "3" 
      "B" "" "" "" "PROP_parMpprResultsDirectory" "" 
      "B" "" "" "" "PROP_parMpprResultsToSave" "" 
      "B" "" "" "" "PROP_parPowerReduction" "false" 
      "B" "" "" "" "PROP_parTimingMode" "Performance Evaluation" 
      "B" "" "" "" "PROP_vcom_otherCmdLineOptions" "" 
      "B" "" "" "" "PROP_vlog_otherCmdLineOptions" "" 
      "B" "" "" "" "PROP_vsim_otherCmdLineOptions" "" 
      "B" "" "" "" "PROP_xcpldFitDesInReg_xbr" "true" 
      "B" "" "" "" "PROP_xcpldFitDesPtermLmt_xbr" "28" 
      "B" "" "" "" "PROP_xilxBitgCfg_GenOpt_DbgBitStr" "false" 
      "B" "" "" "" "PROP_xilxBitgCfg_GenOpt_LogicAllocFile" "false" 
      "B" "" "" "" "PROP_xilxBitgCfg_GenOpt_MaskFile" "false" 
      "B" "" "" "" "PROP_xilxBitgReadBk_GenBitStr" "false" 
      "B" "" "" "" "PROP_xilxMapPackfactor" "100" 
      "B" "" "" "" "PROP_xilxPAReffortLevel" "Standard" 
      "B" "" "" "" "PROP_xstMoveFirstFfStage" "true" 
      "B" "" "" "" "PROP_xstMoveLastFfStage" "true" 
      "B" "" "" "" "PROP_xstROMStyle" "Auto" 
      "B" "" "" "" "PROP_xstSafeImplement" "No" 
      "B" "AutoGeneratedView" "VIEW_Map" "" "PROP_ParSmartGuideFileName" "top_guide.ncd" 
      "B" "AutoGeneratedView" "VIEW_Translation" "" "PROP_MapSmartGuideFileName" "top_guide.ncd" 
      "C" "" "" "" "PROP_CompxlibLang" "VHDL" 
      "C" "" "" "" "PROP_CompxlibSimPath" "Search in Path" 
      "C" "" "" "" "PROP_CompxlibSmartModels" "false" 
      "C" "" "" "" "PROP_CompxlibUpdateIniForSmartModel" "false" 
      "C" "" "" "" "PROP_DevDevice" "xc2vp50" 
      "C" "" "" "" "PROP_DevFamilyPMName" "virtex2p" 
      "C" "" "" "" "PROP_ISimSimulationRunTime_behav_tb" "1000 ns" 
      "C" "" "" "" "PROP_ISimSimulationRunTime_behav_tbw" "1000 ns" 
      "C" "" "" "" "PROP_ISimSimulationRunTime_par_tb" "1000 ns" 
      "C" "" "" "" "PROP_ISimSimulationRunTime_par_tbw" "1000 ns" 
      "C" "" "" "" "PROP_ISimVCDFileName_par_tb" "xpower.vcd" 
      "C" "" "" "" "PROP_ISimVCDFileName_par_tbw" "xpower.vcd" 
      "C" "" "" "" "PROP_MapExtraEffort" "None" 
      "C" "" "" "" "PROP_MapPowerActivityFile" "" 
      "C" "" "" "" "PROP_SimModelGenMultiHierFile" "false" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key0" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key1" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key2" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key3" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key4" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_key5" "" 
      "C" "" "" "" "PROP_bitgen_Encrypt_keyFile" "" 
      "C" "" "" "" "PROP_parPowerActivityFile" "" 
      "C" "" "" "" "PROP_xilxBitgCfg_GenOpt_ReadBack_virtex2" "false" 
      "C" "" "" "" "PROP_xilxPARextraEffortLevel" "None" 
      "D" "" "" "" "PROP_CompxlibUni9000Lib" "true" 
      "D" "" "" "" "PROP_CompxlibUniSimLib" "true" 
      "D" "" "" "" "PROP_DevPackage" "ff1152" 
      "D" "" "" "" "PROP_Synthesis_Tool" "XST (VHDL/Verilog)" 
      "D" "" "" "" "PROP_xilxBitgCfg_GenOpt_LogicAllocFile_virtex2" "false" 
      "D" "" "" "" "PROP_xilxBitgCfg_GenOpt_MaskFile_virtex2" "false" 
      "D" "" "" "" "PROP_xilxBitgReadBk_GenBitStr_virtex2" "false" 
      "E" "" "" "" "PROP_DevSpeed" "-6" 
      "E" "" "" "" "PROP_PreferredLanguage" "Verilog" 
      "F" "" "" "" "PROP_ChangeDevSpeed" "-6" 
      "F" "" "" "" "PROP_HdlTemplateLang" "Verilog" 
      "F" "" "" "" "PROP_SimModelTarget" "Verilog" 
      "F" "" "" "" "PROP_coregenFuncModelTargetLang" "Verilog" 
      "F" "" "" "" "PROP_hdlInstTempTargetLang" "Verilog" 
      "F" "" "" "" "PROP_schFuncModelTargetLang" "Verilog" 
      "F" "" "" "" "PROP_schInstTempTargetLang" "Verilog" 
      "F" "" "" "" "PROP_sysgenInstTempTargetLang" "Verilog" 
      "F" "" "" "" "PROP_tbwTestbenchTargetLang" "Verilog" 
      "F" "" "" "" "PROP_xawHdlSourceTargetLang" "Verilog" 
      "F" "" "" "" "PROP_xilxPostTrceSpeed" "-6" 
      "F" "" "" "" "PROP_xilxPreTrceSpeed" "-6" 
      "F" "" "" "" "PROP_xmpInstTempTargetLang" "Verilog" 
      "G" "" "" "" "PROP_HdlTemplateName" "vp2.v" 
      "G" "" "" "" "PROP_SimModelAutoInsertGlblModuleInNetlist" "true" 
      "G" "" "" "" "PROP_SimModelGenArchOnly" "false" 
      "G" "" "" "" "PROP_SimModelIncSdfAnnInVerilogFile" "true" 
      "G" "" "" "" "PROP_SimModelIncSimprimInVerilogFile" "false" 
      "G" "" "" "" "PROP_SimModelIncUnisimInVerilogFile" "false" 
      "G" "" "" "" "PROP_SimModelIncUselibDirInVerilogFile" "false" 
      "G" "" "" "" "PROP_SimModelNoEscapeSignal" "false" 
      "G" "" "" "" "PROP_SimModelOutputExtIdent" "false" 
      "G" "" "" "" "PROP_SimModelRenTopLevArchTo" "Structure" 
      "G" "" "" "" "PROP_SimModelRenTopLevMod" "" 
      "G" "" "" "" "PROP_bencherPostMapTestbenchName" "test_step_gen.map_tfw" 
      "G" "" "" "" "PROP_bencherPostParTestbenchName" "test_div_steps.timesim_tfw" 
      "G" "" "" "" "PROP_bencherPostXlateTestbenchName" "test_step_gen.translate_tfw" 
      "G" "" "" "" "PROP_netgenPostMapSimModelName" "top_map.v" 
      "G" "" "" "" "PROP_netgenPostParSimModelName" "top_timesim.v" 
      "G" "" "" "" "PROP_netgenPostSynthesisSimModelName" "top_synthesis.v" 
      "G" "" "" "" "PROP_netgenPostXlateSimModelName" "top_translate.v" 
      "G" "AutoGeneratedView" "VIEW_Map" "" "PROP_PostMapSimModelName" "top_map.v" 
      "G" "AutoGeneratedView" "VIEW_Par" "" "PROP_PostParSimModelName" "top_timesim.v" 
      "G" "AutoGeneratedView" "VIEW_Post-MapAbstractSimulation" "" "PROP_tbwPostMapTestbenchName" "test_step_gen.map_tfw" 
      "G" "AutoGeneratedView" "VIEW_Post-ParAbstractSimulation" "" "PROP_tbwPostParTestbenchName" "test_div_steps.timesim_tfw" 
      "G" "AutoGeneratedView" "VIEW_Post-TranslateAbstractSimulation" "" "PROP_tbwPostXlateTestbenchName" "test_step_gen.translate_tfw" 
      "G" "AutoGeneratedView" "VIEW_Structural" "" "PROP_PostSynthesisSimModelName" "top_synthesis.v" 
      "G" "AutoGeneratedView" "VIEW_Translation" "" "PROP_PostXlateSimModelName" "top_translate.v" 
      "H" "" "" "" "PROP_SimModelBringOutGsrNetAsAPort" "false" 
      "H" "" "" "" "PROP_SimModelBringOutGtsNetAsAPort" "false" 
      "H" "" "" "" "PROP_SimModelPathUsedInSdfAnn" "Default" 
      "H" "" "" "" "PROP_netgenRenameTopLevEntTo" "" 
      "I" "" "" "" "PROP_SimModelGsrPortName" "GSR_PORT" 
      "I" "" "" "" "PROP_SimModelGtsPortName" "GTS_PORT" 
      "I" "" "" "" "PROP_SimModelRocPulseWidth" "100" 
      "I" "" "" "" "PROP_SimModelTocPulseWidth" "0"}

  HandleException {
    RestoreProcessProperties $iProjHelper $process_props
  } "A problem occured while restoring process properties."

   # library names and their members
   set libraries {
   }

  HandleException {
    RestoreSourceLibraries $iProjHelper $libraries
  } "A problem occured while restoring source libraries."

   # partition names for recreation
   set partition_names {
   }

  HandleException {
    RestorePartitions $partition_names
  } "A problem occured while restoring partitions."

   set opts_stream [ [Xilinx::Cit::FactoryCreate $::xilinx::Dpm::StreamBufferCompID ]  GetInterface $xilinx::Prjrep::IStreamID ] 
     $opts_stream WriteString "5"
     $opts_stream WriteString "5"
     $opts_stream WriteString "5"
     $opts_stream WriteString "5"
     $opts_stream WriteString "0"
     $opts_stream WriteString "0"
     $opts_stream WriteString "3"
     $opts_stream WriteString "1"
     $opts_stream WriteString "1"
     $opts_stream WriteString "1"
     $opts_stream WriteString "2"
     $opts_stream WriteString "0"
     $opts_stream WriteString "2"
     $opts_stream WriteString "top_guide.ncd"
     $opts_stream WriteString "xpower.vcd"
     $opts_stream WriteString "1"
   RestoreSourceControlOptions "$project_file" $opts_stream
   Release $opts_stream
  if { $srcctrl_comp != 0 } {
     set i_prjref [ $srcctrl_comp GetInterface $::xilinx::Dpm::IProjectHelperReferenceID ]
     $i_prjref Set iProjHelper
  } elseif {$iProjHelper != 0} {
     $iProjHelper Close
  }
  Release $iProjHelper
  # return back
  cd $old_working_dir
}

