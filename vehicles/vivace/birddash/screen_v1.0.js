//console.log("load gaugesScreen");
angular.module('gaugesScreen', [])

  .controller('GaugesScreenController', function ($scope, $element, $window) {
    "use strict";
    var vm = this;

    var svg;

    var speedoDisplay = { };
    var tacho = {  };
    var cellsDescription = {};
    var gaugesCells = {top_left:{},bottom_left:{},top_center:{},bottom_center:{},top_right:{},bottom_right:{},top_bar:{}};
    var widgetCells = {top_left:{},top_right:{},bottom_right:{}}

    var ready = false;
    var customUnits= ["",undefined,"bool","gear","pressureFromPsi","light"]
    var flashInterval = null
    var flashOn = false

    var units = {uiUnitConsumptionRate: "metric",
    uiUnitDate: "ger",
    uiUnitEnergy: "metric",
    uiUnitLength: "metric",
    uiUnitPower: "hp",
    uiUnitPressure: "bar",
    uiUnitTemperature: "c",
    uiUnitTorque: "metric",
    uiUnitVolume: "l",
    uiUnitWeight: "kg"};

    function getNodesArray(prefix,number, root){
      let arr= [];
      for(let i=0;i<number;i++){
        let node = hu(prefix+i, root)
        if(!node)
          console.log(prefix+i,"node not found")
        else
          arr.push(node)
      }
      return arr;
    }

    function getRndInteger(min, max) {
      return Math.floor(Math.random() * (max - min) ) + min;
    }

    // Make sure SVG is loaded
    $scope.onSVGLoaded = function () {
      svg = $element[0].children[0].children[0];

      // speedometer
      speedoDisplay.root = hu('#speedometer', svg);
      speedoDisplay.speedometerText = hu('#speedometerText', speedoDisplay.root)
      speedoDisplay.speedValue = hu('#speed_val', svg);
      speedoDisplay.speedUnit = hu('#speed_unit', svg);
      speedoDisplay.gears = hu('#gear_txt', svg);

      tacho.markers_root = hu('#rpm_markers', svg);
      tacho.markers = getNodesArray("#rpm_markers_",21,tacho.markers_root)

      widgetCells.bottom_right.txt=hu('#botR_txt', svg);
      widgetCells.bottom_right.input=hu('#botR_input', svg);
      widgetCells.bottom_right.input_stop0 = getNodesArray('#input_top0_',4, svg);
      widgetCells.bottom_right.input_stop1 = getNodesArray('#input_top1_',4, svg);
      widgetCells.bottom_right.input_stop2 = getNodesArray('#input_top2_',4, svg);
      widgetCells.top_left.txt=hu('#top_left_3linetxt', svg);
      widgetCells.top_left.wheel=hu('#topL_wheel', svg);
      widgetCells.top_left.wheelTxtFR=hu('#topL_wheelFR_txt', svg);
      widgetCells.top_left.wheelTxtFL=hu('#topL_wheelFL_txt', svg);
      widgetCells.top_left.wheelTxtRR=hu('#topL_wheelRR_txt', svg);
      widgetCells.top_left.wheelTxtRL=hu('#topL_wheelRL_txt', svg);
      widgetCells.top_left.wheelRectFR=hu('#topL_wheelFR_r', svg);
      widgetCells.top_left.wheelRectFL=hu('#topL_wheelFL_r', svg);
      widgetCells.top_left.wheelRectRR=hu('#topL_wheelRR_r', svg);
      widgetCells.top_left.wheelRectRL=hu('#topL_wheelRL_r', svg);


      gaugesCells.bottom_left.lbl = hu('#bottom_left_lbl', svg);
      gaugesCells.bottom_left.unit = hu('#bottom_left_unit', svg);
      gaugesCells.bottom_left.val = hu('#bottom_left_val', svg);

      gaugesCells.bottom_center.val = hu('#bottom_center_val', svg);
      gaugesCells.top_center.val = hu('#top_center_val', svg);
      gaugesCells.top_center.tspan = hu('#tspan919', svg);
      gaugesCells.top_center.esc = hu('#escLight', svg);
      gaugesCells.top_center.abs = hu('#absLight', svg);
      gaugesCells.top_center.tcs = hu('#tcsLight', svg);

      gaugesCells.top_left.lbl = getNodesArray('#top_left_lbl',3, svg);
      gaugesCells.top_left.val = getNodesArray('#top_left_val',3, svg);

      gaugesCells.top_right.lbl = getNodesArray('#top_right_lbl',3, svg);
      gaugesCells.top_right.val = getNodesArray('#top_right_val',3, svg);

      gaugesCells.bottom_right.lbl = getNodesArray('#bottom_right_lbl',2, widgetCells.bottom_right.txt);
      gaugesCells.bottom_right.val = getNodesArray('#bottom_right_val',2, widgetCells.bottom_right.txt);

      gaugesCells.top_bar.lbl = hu('#top_bar_lbl', svg);
      gaugesCells.top_bar.val = hu('#top_bar_val', svg);
      gaugesCells.top_bar.path = hu('#rpm_path', svg);
      gaugesCells.top_bar.rpm_path_l = hu('#rpm_path_l', svg);
      gaugesCells.top_bar.stops = getNodesArray('#rpm_stop_', 4, svg);
      gaugesCells.top_bar.l_stops = getNodesArray('#rpm_path_l_', 4, svg);
      gaugesCells.top_bar.r_stops = getNodesArray('#rpm_path_r_', 4, svg);
      gaugesCells.top_bar.rpm_high_rect = hu('#rpm_high_rect', svg);


      ready = true;
    }

    function limitVal(min, val,max){
      return Math.min(Math.max(min,val), max);
    }
    function map_range(value, low1, high1, low2, high2) {
      return low2 + (high2 - low2) * (value - low1) / (high1 - low1);
    }
    const clamp = (num, min, max) => Math.min(Math.max(num, min), max);
    const clamp_remap = (val, min,max) => map_range(clamp(val,min,max), min,max,0,1);

    //https://stackoverflow.com/a/39077686
    const hexToRgb = hex =>
      hex.replace(/^#?([a-f\d])([a-f\d])([a-f\d])$/i
                ,(m, r, g, b) => '#' + r + r + g + g + b + b)
        .substring(1).match(/.{2}/g)
        .map(x => parseInt(x, 16))
    const rgbParse = rgbStr => rgbStr.replace(/[^\d,]/g, '').split(',').map(Number);

    const invalidUnit = (unit) => {
      return typeof UiUnits[unit] !== 'function' && !customUnits.includes(unit)
    }

    function setGradiantStops(gradiantStops, pcFloat) {
      gradiantStops[1].attr({offset: pcFloat-pcFloat*0.0001})
      gradiantStops[2].attr({offset: pcFloat})
    }

    function getUnit(cellsDescription, currentCell){
      switch(cellsDescription[currentCell].unit){
        case "":
        case undefined:
        case "bool":
        case "gear":
        case "light":
          return ''
        case "pressureFromPsi":
          return UiUnits["pressure"](0).unit
        default:
          return UiUnits[cellsDescription[currentCell].unit](0).unit
      }
    }

    // overwriting plain javascript function so we can access from within the controller
    $window.setup = (data) => {
      if(!ready){
        console.log("calling setup while svg not fully loaded");
        setTimeout(function(){ $window.setup(data) }, 100);
        return;
      }

      console.log("setup",data);
      for(let dk in data){
        if(typeof dk == "string" && dk.startsWith("uiUnit")){
          units[dk] = data[dk];
        }
      }
      vueEventBus.emit('SettingsChanged', {values:units})

      cellsDescription = data.cells

      if ("bottom_left" in cellsDescription){
        gaugesCells.bottom_left.lbl.text(cellsDescription.bottom_left.label)
        if(invalidUnit(cellsDescription.bottom_left.unit)){
          console.log("bottom_left unknown unit type", cellsDescription.bottom_left.unit)
          delete cellsDescription.bottom_left
        }else{
          gaugesCells.bottom_left.unit.text(getUnit(cellsDescription,"bottom_left"))
        }
      }else{
        gaugesCells.bottom_left.lbl.text("")
        gaugesCells.bottom_left.unit.text("")
        gaugesCells.bottom_left.val.text("")
      }

      if ("top_left" in cellsDescription){
        widgetCells.top_left.txt.n.style.display = cellsDescription.top_left.widgetCells=="text"?"inline":"none";
        widgetCells.top_left.wheel.n.style.display = cellsDescription.top_left.widgetCells=="wheel"?"inline":"none";
        if ("top_left0" in cellsDescription){
          gaugesCells.top_left.lbl[0].text(cellsDescription.top_left0.label)
          if(invalidUnit(cellsDescription.top_left0.unit)){
            console.log("top_left0 unknown unit type", cellsDescription.top_left0.unit)
            delete cellsDescription.top_left0
          }
        }else{
          gaugesCells.top_left.lbl[0].text("")
          gaugesCells.top_left.val[0].text("")
        }
        if ("top_left1" in cellsDescription){
          gaugesCells.top_left.lbl[1].text(cellsDescription.top_left1.label)
          if(invalidUnit(cellsDescription.top_left1.unit)){
            console.log("top_left1 unknown unit type", cellsDescription.top_left1.unit)
            delete cellsDescription.top_left1
          }
        }else{
          gaugesCells.top_left.lbl[1].text("")
          gaugesCells.top_left.val[1].text("")
        }
        if ("top_left2" in cellsDescription){
          gaugesCells.top_left.lbl[2].text(cellsDescription.top_left2.label)
          if(invalidUnit(cellsDescription.top_left2.unit)){
            console.log("top_left2 unknown unit type", cellsDescription.top_left2.unit)
            delete cellsDescription.top_left2
          }
        }else{
          gaugesCells.top_left.lbl[2].text("")
          gaugesCells.top_left.val[2].text("")
        }
      }
      else{
        console.log("top_left widgetCells undefined")
      }
      if ("bottom_center" in cellsDescription){
        if(invalidUnit(cellsDescription.bottom_center.unit)){
          console.log("bottom_center unknown unit type", cellsDescription.bottom_center.unit)
          delete cellsDescription.bottom_center
        }
      }else{
        gaugesCells.bottom_center.val.text("")
      }
      if ("top_center" in cellsDescription){
        if(invalidUnit(cellsDescription.top_center.unit)){
          console.log("top_center unknown unit type", cellsDescription.top_center.unit)
          delete cellsDescription.top_center
        }
      }else{
        gaugesCells.top_center.val.text("")
      }
      if ("top_bar" in cellsDescription){
        gaugesCells.top_bar.lbl.text(cellsDescription.top_bar.label)
        if(invalidUnit(cellsDescription.top_bar.unit)){
          console.log("top_bar unknown unit type", cellsDescription.top_bar.unit)
          delete cellsDescription.top_bar
        }
      }else{
        gaugesCells.top_bar.lbl.text("")
        gaugesCells.top_bar.val.text("")
        setGradiantStops(gaugesCells.top_bar.stops, 0)
        setGradiantStops(gaugesCells.top_bar.l_stops, 0)
        setGradiantStops(gaugesCells.top_bar.r_stops, 0)
      }

      gaugesCells.top_bar.rpm_high_rect.n.style.display = "none";

      if ("top_right0" in cellsDescription){
        gaugesCells.top_right.lbl[0].text(cellsDescription.top_right0.label)
        if(invalidUnit(cellsDescription.top_right0.unit)){
          console.log("top_right0 unknown unit type", cellsDescription.top_right0.unit)
          delete cellsDescription.top_right0
        }
      }else{
        gaugesCells.top_right.lbl[0].text("")
        gaugesCells.top_right.val[0].text("")
      }
      if ("top_right1" in cellsDescription){
        gaugesCells.top_right.lbl[1].text(cellsDescription.top_right1.label)
        if(invalidUnit(cellsDescription.top_right1.unit)){
          console.log("top_right1 unknown unit type", cellsDescription.top_right1.unit)
          delete cellsDescription.top_right1
        }
      }else{
        gaugesCells.top_right.lbl[1].text("")
        gaugesCells.top_right.val[1].text("")
      }
      if ("top_right2" in cellsDescription){
        gaugesCells.top_right.lbl[2].text(cellsDescription.top_right2.label)
        if(invalidUnit(cellsDescription.top_right2.unit)){
          console.log("top_right2 unknown unit type", cellsDescription.top_right2.unit)
          delete cellsDescription.top_right2
        }
      }else{
        gaugesCells.top_right.lbl[2].text("")
        gaugesCells.top_right.val[2].text("")
      }

      if ("bottom_right" in cellsDescription){
        widgetCells.bottom_right.txt.n.style.display = cellsDescription.bottom_right.widgetCells=="text"?"inline":"none";
        widgetCells.bottom_right.input.n.style.display = cellsDescription.bottom_right.widgetCells=="input"?"inline":"none";
        if ("bottom_right0" in cellsDescription){
          gaugesCells.bottom_right.lbl[0].text(cellsDescription.bottom_right0.label)
          if(invalidUnit(cellsDescription.bottom_right0.unit)){
            console.log("bottom_right0 unknown unit type", cellsDescription.bottom_right0.unit)
            delete cellsDescription.bottom_right0
          }
        }else{
          gaugesCells.bottom_right.lbl[0].text("")
          gaugesCells.bottom_right.val[0].text("")
        }
        if ("bottom_right1" in cellsDescription){
          gaugesCells.bottom_right.lbl[1].text(cellsDescription.bottom_right1.label)
          if(invalidUnit(cellsDescription.bottom_right1.unit)){
            console.log("bottom_right1 unknown unit type", cellsDescription.bottom_right1.unit)
            delete cellsDescription.bottom_right1
          }
        }else{
          gaugesCells.bottom_right.lbl[1].text("")
          gaugesCells.bottom_right.val[1].text("")
        }
      }
      else{
        console.log("bottom_right widgetCells undefined")
      }
    }

    //https://stackoverflow.com/a/56266358
    function isColor(strColor){
      var s = new Option().style;
      s.color = strColor;
      return s.color !== "";
    }

    function gearToStr(val){
      if(isNaN(val)) //probably string
        return val
      if(val==0)
        return "N"
      if(val==-1)
        return "R"
      if(val< -1)
        return "R"+Math.abs(val)
      return val.toFixed(0)
    }

    function getValueFromPath(data,path){
      let splittedPath = path.split('.');
      let dataStack = data;
      for( let p in splittedPath){
        if(! (splittedPath[p] in dataStack)){
          console.log("path undefined ",splittedPath[p] , "complete=", path);
          return 0;
        }
        dataStack = dataStack[splittedPath[p]]
      }
      return dataStack
    }

    function getUiUnitFromPath(data, cellsDescription, currentCell){
      let cellName = currentCell.indexOf('.')> -1? currentCell.split('.')[0]:currentCell;
      let path = currentCell.indexOf('.')> -1? cellsDescription[cellName][currentCell.split('.')[1]]:cellsDescription[currentCell].path;
      switch(cellsDescription[cellName].unit){
        case "":
        case undefined: //because CEF...
          return { val: getValueFromPath(data,path), unit: ''}
        case "bool":
          let v = getValueFromPath(data,path);
          return { val: (v===true||v>0.5)?"TRUE":"FALSE", unit: ''}
        case "gear":
          return { val: gearToStr(getValueFromPath(data,path)), unit: ''}
        case "light":
          switch( Math.round(getValueFromPath(data,path))){
            case 0:
              return { val: "OFF", unit: ''}
            case 1:
              return { val: "LOW", unit: ''}
            case 2:
              return { val: "HIGH", unit: ''}
            default:
              return { val: "???", unit: ''}
          }
        case "pressureFromPsi":
          return UiUnits["pressure"](getValueFromPath(data,path)*6.89476)
        case "consumptionRate":
          return UiUnits["consumptionRate"](getValueFromPath(data,path)* 1e-5)
        default:
          return UiUnits[cellsDescription[cellName].unit](getValueFromPath(data,path))
      }
    }

    //TODO not compatible with path
    function displayNum(UIunitval, cellsDescription, currentCell){
      let cellName = currentCell.indexOf('.')> -1? currentCell.split('.')[0]:currentCell;
      let tenPrecision= ("tenPrecision" in cellsDescription[cellName])?cellsDescription[cellName]["tenPrecision"]:1
      let maxPrecision= ("maxPrecision" in cellsDescription[cellName])?cellsDescription[cellName]["maxPrecision"]:0
      if (isNaN(UIunitval.val) || typeof UIunitval.val == "string") return UIunitval.val
      return Math.abs(UIunitval.val)<10 ? UIunitval.val.toFixed(tenPrecision) : UIunitval.val.toFixed(maxPrecision)
    }

    function resizeText(node, maxWidth){
      let bbox = node.n.getBBox()
      if(bbox.width < maxWidth*3){
        node.n.style.fontSize = ""
        bbox = node.n.getBBox()
      }
      let style = window.getComputedStyle(node.n, null).getPropertyValue('font-size');
      let fontSize = parseFloat(style);
      while(bbox.width > maxWidth*3.3){
        fontSize *= 0.9
        node.n.style.fontSize = fontSize + "px"
        bbox = node.n.getBBox()
      }
    }

    $window.updateData = (data) => {
      if (data) {
        if(!ready){console.log("not ready");return;}
         //console.log(data);

        if ("bottom_left" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "bottom_left")
          gaugesCells.bottom_left.val.text( displayNum(val,cellsDescription, "bottom_left")  );
        }

        if ("bottom_center" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "bottom_center")
          gaugesCells.bottom_center.val.text( displayNum(val,cellsDescription, "bottom_center") );
          resizeText(gaugesCells.bottom_center.val, 360)
        }
        if ("top_center" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "top_center")
          gaugesCells.top_center.val.text( displayNum(val,cellsDescription, "top_center") );
          resizeText(gaugesCells.top_center.val, 360)
        }
        if ("top_bar" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "top_bar")
          gaugesCells.top_bar.val.text( displayNum(val,cellsDescription, "top_bar") );
          let maxval = getValueFromPath(data,cellsDescription["top_bar"].max);
          if(maxval==0) maxval=1000;

          let rpmRange = 3000
          let stepsCount = 6
          let maxRpm = maxval
          let minRpm = maxRpm - rpmRange
          let rpmStepRange = maxRpm - minRpm
          let rpmStep = rpmStepRange / stepsCount
          let steps = 2
          let finalRange = rpmStep * steps

          // let thresh = 0.8
          // let shift_rpm = 6500
          // let shift_rpm = maxval - stepSize
          let shift_rpm = maxRpm - finalRange

          // let maxval_adjusted = maxval * thresh
          let theVal = val.val
          // let pct = theVal/maxval
          // let pct_adjusted = theVal/maxval_adjusted

          let pct_adjusted = theVal/shift_rpm

          if (pct_adjusted > 1.0) {
            pct_adjusted = 1.0
          }

          let overShiftRpm = theVal > shift_rpm

          if (overShiftRpm) {
            if (!flashInterval) {
              flashOn = false
              flashInterval = setInterval(() => {
                // console.log('fhashy')
                flashOn = !flashOn
              }, 100)
            }
          } else {
            clearInterval(flashInterval)
            flashOn = false
            flashInterval = null
          }

          // console.log(`${theVal} / ${maxval_adjusted} (${pct_adjusted})`)
          // setGradiantStops(gaugesCells.top_bar.stops, pct)
          setGradiantStops(gaugesCells.top_bar.l_stops, pct_adjusted)
          setGradiantStops(gaugesCells.top_bar.r_stops, pct_adjusted)

          let black = "#000000"
          let green = "#04ff00"

          // gaugesCells.top_bar.rpm_high_rect.n.style.display = pct > thresh ? "inline" : "none";
          if (flashOn) {
            gaugesCells.top_bar.rpm_high_rect.n.style.display = overShiftRpm ? "none" : "inline";
            gaugesCells.top_center.tspan.n.style.fill = overShiftRpm ? black : green
            // gaugesCells.top_center.tspan.attr({fill: "#000000"})
            // gaugesCells.top_center.val.css({fill:"#000000"})
          } else {
            gaugesCells.top_bar.rpm_high_rect.n.style.display = overShiftRpm ? "inline" : "none";
            gaugesCells.top_center.tspan.n.style.fill =  overShiftRpm ? black : green
            // gaugesCells.top_center.tspan.attr({fill: "#04ff00"})
            // gaugesCells.top_center.val.css({fill:"#04ff00"})
          }
        }

        if("top_left" in cellsDescription){
          if(cellsDescription.top_left.widgetCells == "text"){
            if ("top_left0" in cellsDescription){
              let val = getUiUnitFromPath(data,cellsDescription, "top_left0")
              gaugesCells.top_left.val[0].text( displayNum(val,cellsDescription, "top_left0") )
            }
            if ("top_left1" in cellsDescription){
              let val = getUiUnitFromPath(data,cellsDescription, "top_left1")
              gaugesCells.top_left.val[1].text( displayNum(val,cellsDescription, "top_left1") )
            }
            if ("top_left2" in cellsDescription){
              let val = getUiUnitFromPath(data,cellsDescription, "top_left2")
              gaugesCells.top_left.val[2].text( displayNum(val,cellsDescription, "top_left2") )
            }
          }else if(cellsDescription.top_left.widgetCells == "wheel"){
            let val = getUiUnitFromPath(data,cellsDescription, "top_left.FR")
            widgetCells.top_left.wheelTxtFR.text(displayNum(val,cellsDescription, "top_left.FR"))
            val = getUiUnitFromPath(data,cellsDescription, "top_left.FL")
            widgetCells.top_left.wheelTxtFL.text(displayNum(val,cellsDescription, "top_left.FL"))
            val = getUiUnitFromPath(data,cellsDescription, "top_left.RR")
            widgetCells.top_left.wheelTxtRR.text(displayNum(val,cellsDescription, "top_left.RR"))
            val = getUiUnitFromPath(data,cellsDescription, "top_left.RL")
            widgetCells.top_left.wheelTxtRL.text(displayNum(val,cellsDescription, "top_left.RL"))

            if(cellsDescription.top_left.FLcolor)
              widgetCells.top_left.wheelRectFL.css({fill:getValueFromPath(data,cellsDescription.top_left.FLcolor)})
            if(cellsDescription.top_left.FRcolor)
              widgetCells.top_left.wheelRectFR.css({fill:getValueFromPath(data,cellsDescription.top_left.FRcolor)})
            if(cellsDescription.top_left.RLcolor)
              widgetCells.top_left.wheelRectRL.css({fill:getValueFromPath(data,cellsDescription.top_left.RLcolor)})
            if(cellsDescription.top_left.RRcolor)
              widgetCells.top_left.wheelRectRR.css({fill:getValueFromPath(data,cellsDescription.top_left.RRcolor)})
          }
        }

        if ("top_right0" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "top_right0")
          gaugesCells.top_right.val[0].text( displayNum(val,cellsDescription, "top_right0") )
        }
        if ("top_right1" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "top_right1")
          gaugesCells.top_right.val[1].text( displayNum(val,cellsDescription, "top_right1") )
        }
        if ("top_right2" in cellsDescription){
          let val = getUiUnitFromPath(data,cellsDescription, "top_right2")
          gaugesCells.top_right.val[2].text( displayNum(val,cellsDescription, "top_right2") )
        }

        if("bottom_right" in cellsDescription){
          if(cellsDescription.bottom_right.widgetCells == "text"){
            if ("bottom_right0" in cellsDescription){
              let val = getUiUnitFromPath(data,cellsDescription, "bottom_right0")
              gaugesCells.bottom_right.val[0].text( displayNum(val,cellsDescription, "bottom_right0") )
            }
            if ("bottom_right1" in cellsDescription){
              let val = getUiUnitFromPath(data,cellsDescription, "bottom_right1")
              gaugesCells.bottom_right.val[1].text( displayNum(val,cellsDescription, "bottom_right1") )
            }
          }else if(cellsDescription.bottom_right.widgetCells == "input"){
            setGradiantStops(widgetCells.bottom_right.input_stop0, getValueFromPath(data,cellsDescription["bottom_right"].bar0_path ))
            setGradiantStops(widgetCells.bottom_right.input_stop1, getValueFromPath(data,cellsDescription["bottom_right"].bar1_path ))
            setGradiantStops(widgetCells.bottom_right.input_stop2, getValueFromPath(data,cellsDescription["bottom_right"].bar2_path ))
          }
        }

        gaugesCells.top_center.esc.n.style.display = (data.electrics["hasESC"]===1) ?"inline":"none";
        if(data.electrics["hasESC"] !== undefined){
          if( gaugesCells.top_center.esc.n.classList.contains("blink") !== (data.electrics["hasESC"]===1) && data.electrics["escActive"]){
            gaugesCells.top_center.esc.n.classList.toggle("blink", data.electrics["hasESC"]===1);
          }
          if(gaugesCells.top_center.esc.n.classList.contains("blink") && !data.electrics["escActive"]){
            gaugesCells.top_center.esc.n.classList.remove("blink");
          }
        }
        gaugesCells.top_center.abs.n.style.display = (data.electrics["hasABS"]===1) ?"inline":"none";
        if(data.electrics["hasABS"] !== undefined){
          if( gaugesCells.top_center.abs.n.classList.contains("blink") !== (data.electrics["hasABS"]===1) && data.electrics["absActive"]){
            gaugesCells.top_center.abs.n.classList.toggle("blink", data.electrics["hasABS"]===1);
          }
          if(gaugesCells.top_center.abs.n.classList.contains("blink") && !data.electrics["absActive"]){
            gaugesCells.top_center.abs.n.classList.remove("blink");
          }
        }
        gaugesCells.top_center.tcs.n.style.display = (data.electrics["hasTCS"]===1) ?"inline":"none";
        if(data.electrics["hasTCS"] !== undefined){
          if( gaugesCells.top_center.tcs.n.classList.contains("blink") !== (data.electrics["hasTCS"]===1) && data.electrics["tcsActive"]){
            gaugesCells.top_center.tcs.n.classList.toggle("blink", data.electrics["hasTCS"]===1);
          }
          if(gaugesCells.top_center.tcs.n.classList.contains("blink") && !data.electrics["tcsActive"]){
            gaugesCells.top_center.tcs.n.classList.remove("blink");
          }
        }
      }
    }

    $window.updateMode = (data) => {}

    function getRndFloat(min, max) {
      return Math.random() * (max - min) + min;
    }

    function getRndColor() {
      return "#" + Math.floor(Math.random()*16777215).toString(16);
    }

    function demo(){
      updateData(
        {electrics: {
          lowfuel: Math.random()>0.5, fuel: Math.random(), watertemp: getRndInteger(40,130),
          rpmTacho: getRndInteger(0,60000), maxrpm:10000, oiltemp:getRndInteger(40,130),
          turboBoost:getRndFloat(0,5), engineRunning:Math.random()>0.5,
          signal_L:Math.random(), signal_R:Math.random(), lights:Math.random()*2,
          highbeam:Math.random(), lowpressure:Math.random(), parkingbrake:Math.random(),
          checkengine:Math.random(), gear:"M"+getRndInteger(1,7), wheelspeed: getRndInteger(0,20)/3.6,
          hasABS: getRndInteger(0,2), absActive: Math.random()>0.5, hasESC: getRndInteger(0,2), escActive: Math.random()>0.5,
          hasTCS: getRndInteger(0,2), tcsActive: Math.random()>0.5,
        },
        customModules: {
          accelerationData: {xSmooth:getRndFloat(-20,20) ,ySmooth:getRndFloat(-20,20)},
          environmentData:{time:getRndInteger(0,23)+":"+getRndInteger(0,59), temperatureEnv:Math.random()*100-50},
          dynamicRedlineData:{yellow:12,red:14,shiftLight:false},
          tireData:{
            pressures:{FL:Math.random()*200,FR:Math.random()*200,RL:Math.random()*200,RR:Math.random()*200},
            temperatures:{FL:getRndColor(),FR:getRndColor(),RL:getRndColor(),RR:getRndColor()}
          },
          combustionEngineData:{fuelDisplay:Math.random()*50,averageFuelConsumption:Math.random()*50,currentFuelConsumption:Math.random()*50,remainingRange:Math.random()*200}
        }});
      setTimeout(demo, 2000);
    }
    if(typeof beamng == 'undefined' || typeof beamng.sendActiveObjectLua == 'undefined') { //mode demo only in external browser
      console.log("Demo mode")
      setup({cells:{
        bottom_left: {label: "tENV", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
        bottom_center: {label: "", unit:"speed", path:"electrics.wheelspeed"},
        //top_center: {label: "", unit:"gear", path:"electrics.gear"},
        top_center: {label: "", unit:"speed", path:"electrics.rpmTacho",tenPrecision:0},
        top_bar: {label: "DEMO!!", unit:"", path:"electrics.rpmTacho", max:"electrics.maxrpm"},
        top_left: {widgetCells: "wheel", unit:"pressure",
        FR:"customModules.tireData.pressures.FR", FL:"customModules.tireData.pressures.FL",
        RR:"customModules.tireData.pressures.RR", RL:"customModules.tireData.pressures.RL",
        FRcolor:"customModules.tireData.temperatures.FR", FLcolor:"customModules.tireData.temperatures.FL",
        RRcolor:"customModules.tireData.temperatures.RR", RLcolor:"customModules.tireData.temperatures.RL"},
        top_left0: {label: "tENV0", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
        top_left1: {label: "tENVl1", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
        top_left2: {label: "tENVl2", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
        top_right0: {label: "run", unit:"bool", path:"electrics.engineRunning"},
        top_right1: {label: "light", unit:"light", path:"electrics.lights"},
        top_right2: {label: "tENVr2", path:"customModules.environmentData.temperatureEnv"},
        bottom_right: {widgetCells: "input", bar0_path:"electrics.fuel", bar1_path:"electrics.fuel", bar2_path:"electrics.fuel"},
        bottom_right0: {label: "tENVr3", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
        bottom_right1: {label: "tENVr4", unit:"temperature", path:"customModules.environmentData.temperatureEnv"},
      }})
      setTimeout(()=>{demo()} , 500);
    }
    //ready = true;
  });
