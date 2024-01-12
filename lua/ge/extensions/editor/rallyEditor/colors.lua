local M = {}

--
-- colors
--
M.clr_white       = {1.0, 1.0, 1.0}
M.clr_black       = {0.0, 0.0, 0.0}
M.clr_green       = {0.0, 1.0, 0.0}
M.clr_red         = {1.0, 0.0, 0.0}
M.clr_blue        = {0.0, 0.0, 1.0}
M.clr_orange      = {1.0, 0.64, 0.0}
M.clr_pink        = {1.0, 0.0, 1.0}
M.clr_light_green = {0.5, 1.0, 0.5}
M.clr_light_red   = {1.0, 0.5, 0.5}
M.clr_lime_green  = {0.66, 1.0, 0.0}
M.clr_aqua        = {0.0, 0.8, 0.8}

M.clr_grey        = {0.5, 0.5, 0.5}
M.clr_grey_light  = {0.75, 0.75, 0.75}


------------------------------------------------------------------------------

--
-- snaproads.lua
--
M.snaproads_radius = 1.5
M.snaproads_alpha = 0.3
M.snaproads_alpha_hover = 0.9
M.snaproads_clr = M.clr_red
M.snaproads_clr_hover = M.clr_white

local clr_at = M.clr_blue
local clr_di = M.clr_orange
local clr_label_fg = M.clr_white
local clr_label_bg = M.clr_black

--
-- pacenote.lua
--
-- M.pacenote_alpha_shape_normal = 0.25
-- M.pacenote_alpha_txt_normal = 0.5
--
-- M.pacenote_alpha_shape_selected = 0.8
-- M.pacenote_alpha_txt_selected = 1.0
--
-- M.pacenote_alpha_shape_previous = 0.25
-- M.pacenote_alpha_txt_previous = 0.5

M.pacenote_alpha_interlink = 1.0

M.pacenote_shapeAlpha_factor = 0.8

M.pacenote_base_alpha_normal = 0.5
M.pacenote_base_alpha_prev   = 0.5
M.pacenote_base_alpha_next   = 0.5
M.pacenote_base_alpha_selected = 1.0


M.pacenote_linkHeightRadiusShinkFactor = 0.5
M.pacenote_linkFromWidth = 1.5
M.pacenote_linkToWidth = 0.25

M.pacenote_clr_interlink = M.clr_pink
M.pacenote_clr_interlink_txt = M.clr_black
M.pacenote_clr_cs_to_ce_direct = M.clr_grey_light
M.pacenote_clr_at = clr_at
M.pacenote_clr_di = clr_di
M.pacenote_clr_di_txt = M.clr_black
M.pacenote_clr_link_fg = clr_label_fg
M.pacenote_clr_link_bg = clr_label_bg

--
-- pacenoteWaypoint.lua
--
M.waypoint_clr_cs = M.clr_green
M.waypoint_clr_ce = M.clr_red
M.waypoint_clr_di = clr_di
M.waypoint_clr_at = clr_at
M.waypoint_clr_txt_fg = clr_label_fg
M.waypoint_clr_txt_bg = clr_label_bg
M.waypoint_clr_sphere_hover = M.clr_white
M.waypoint_clr_sphere_selected = M.clr_white

M.waypoint_shapeAlpha_hover = 1.0
M.waypoint_textAlpha_hover = 1.0
M.waypoint_sphereAlphaReducionForArrowFactor = 0.6
-- M.waypoint_shapeAlpha_arrowAdjustFactor = 1.25
M.waypoint_shapeAlpha_arrowPlaneAdjustFactor = 0.66

--
-- rallyEditor/pacenotes.lua
--
M.new_pacenote_cursor_clr_link = M.clr_white
M.new_pacenote_cursor_clr_cs = M.clr_light_green
M.new_pacenote_cursor_clr_ce = M.clr_light_red
M.new_pacenote_cursor_alpha = 0.8
M.new_pacenote_cursor_linkHeightRadiusShinkFactor = 0.5
M.new_pacenote_cursor_linkFromWidth = 1.0
M.new_pacenote_cursor_linkToWidth = 0.25

-- M.segments_alpha = 0.5
-- M.segments_clr_assigned = M.clr_white
-- M.segments_clr = M.clr_aqua

return M
