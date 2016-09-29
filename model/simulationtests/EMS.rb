
require 'openstudio'
require 'lib/baseline_model'

model = BaselineModel.new

#make a 2 story, 100m X 50m, 10 zone core/perimeter building
model.add_geometry({"length" => 100,
              "width" => 50,
              "num_floors" => 2,
              "floor_to_floor_height" => 4,
              "plenum_height" => 1,
              "perimeter_zone_depth" => 3})

#add windows at a 40% window-to-wall ratio
model.add_windows({"wwr" => 0.4,
                  "offset" => 1,
                  "application_type" => "Above Floor"})
        
#add ASHRAE System type 03, PSZ-AC
model.add_hvac({"ashrae_sys_num" => '03'})

#add thermostats
model.add_thermostats({"heating_setpoint" => 24,
                      "cooling_setpoint" => 28})
              
#assign constructions from a local library to the walls/windows/etc. in the model
model.set_constructions()

#set whole building space type; simplified 90.1-2004 Large Office Whole Building
model.set_space_type()  

#add design days to the model (Chicago)
model.add_design_days()

   # Create an output variable for OATdb
    output_var = "Site Outdoor Air Drybulb Temperature"
    output_var_oat = OpenStudio::Model::OutputVariable.new(output_var, model)

   # Create a sensor to sense the outdoor air temperature
    oat_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model)
    oat_sensor_name = "OATdb Sensor"
    oat_sensor.setName(oat_sensor_name)
    oat_sensor.setOutputVariable(output_var_oat)

   # Actuator ###

   # Get the first fan from the example model
    #fan = model.getFanConstantVolumes[0]
    always_on = model.alwaysOnDiscreteSchedule
    fan = OpenStudio::Model::FanConstantVolume.new(model,always_on)

   # Create an actuator to set the fan pressure rise
    fan_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(fan)
    fan_actuator.setName("#{fan.name} Press Actuator")
    fan_press = "Fan Pressure Rise"
    fan_actuator.setActuatedComponentControlType(fan_press)
    fan_actuator.setActuatedComponentType("fan")
    fan_actuator.setActuatedComponent(fan)
    ## Program ###

    # Create a program all at once
    fan_program_1 = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fan_program_1.setName("#{fan.name} Pressure Rise Program")
    fan_program_1_body = <<-EMS
      SET mult = #{oat_sensor.handle} / 15.0 !- This is nonsense
      SET #{fan_actuator.handle} = 250 * mult !- More nonsense
    EMS
    fan_program_1.setBody(fan_program_1_body)
       
    # Create a second program from a vector of lines
    fan_program_2 = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    fan_program_2.setName("#{fan.name} Pressure Rise Program by Line")
    fan_program_2.addLine("SET mult = #{oat_sensor.handle} / 15.0 !- This is nonsense")
    fan_program_2.addLine("SET #{fan_actuator.handle} = 250 * mult !- More nonsense")
    
    # Create a programcallingmanager
    fan_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    fan_pcm.addProgram(fan_program_1)
    fan_pcm.addProgram(fan_program_2)
    
#save the OpenStudio model (.osm)
model.save_openstudio_osm({"osm_save_directory" => Dir.pwd,
                           "osm_name" => "out.osm"})
                           
