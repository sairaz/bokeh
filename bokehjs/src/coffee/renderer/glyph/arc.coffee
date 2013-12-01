
define [
  "underscore",
  "renderer/properties",
  "./glyph",
], (_, Properties, Glyph) ->

  glyph_properties = Properties.glyph_properties
  line_properties  = Properties.line_properties

  class ArcView extends Glyph.View

    initialize: (options) ->
      glyphspec = @mget('glyphspec')
      @glyph_props = new glyph_properties(
        @,
        glyphspec,
        ['x', 'y', 'radius', 'start_angle', 'end_angle', 'direction:string'],
        {
          line_properties: new line_properties(@, glyphspec)
        }
      )

      @do_stroke = @glyph_props.line_properties.do_stroke
      super(options)

    _set_data: (@data) ->
      @x = @glyph_props.v_select('x', data)
      @y = @glyph_props.v_select('y', data)
      # TODO (bev) handle degrees in addition to radians
      start_angle = @glyph_props.v_select('start_angle', data)
      @start_angle = (-angle for angle in start_angle)
      end_angle = @glyph_props.v_select('end_angle', data)
      @end_angle = (-angle for angle in end_angle)
      @direction = new Uint8Array(@data.length)
      for i in [0..@data.length-1]
        dir = @glyph_props.select('direction', data[i])
        if dir == 'clock' then @direction[i] = false
        else if dir == 'anticlock' then @direction[i] = true
        else @direction[i] = NaN


    set_data: (request_render=true) ->
      source = @mget_obj('data_source')
      if source.type == 'ColumnDataSource'
        @x = @glyph_props.source_v_select('x', source)
        @y = @glyph_props.source_v_select('y', source)
        start_angles = @glyph_props.source_v_select('start_angle', source)
        @start_angle = (-angle for angle in start_angles)
        end_angles = @glyph_props.source_v_select('end_angle', source)
        @end_angle = (-angle for angle in end_angles)

        @direction = new Uint8Array(source.get_length())
        for i in [0..@direction.length-1]
          #FIXME
          dir = @glyph_props.select('direction', data[i])
          if dir == 'clock' then @direction[i] = false
          else if dir == 'anticlock' then @direction[i] = true
          else @direction[i] = NaN


        @mask = new Uint8Array(@x.length)
        @selected_mask = new Uint8Array(@x.length)
        for i in [0..@mask.length-1]
          @mask[i] = true
          @selected_mask[i] = false
        @have_new_data = true
  
      if request_render
        @request_render()

    _render: () ->
      [@sx, @sy] = @plot_view.map_to_screen(@x, @glyph_props.x.units, @y, @glyph_props.y.units)
      @radius = @distance(@data, 'x', 'radius', 'edge')

      ctx = @plot_view.ctx

      ctx.save()
      @_full_path(ctx)
      ctx.restore()

    _full_path: (ctx) ->
      if @do_stroke
        source = @mget_obj('data_source')
        glyph_props.line_properties.set_prop_cache(source)
        ctx.beginPath()
        for i in [0..@sx.length-1]
          if isNaN(@sx[i] + @sy[i] + @radius[i] + @start_angle[i] + @end_angle[i] + @direction[i])
            continue
          if glyph_props.line_properties.set_vectorize(ctx, i)
            ctx.stroke()
            ctx.beginPath()
          ctx.arc(@sx[i], @sy[i], @radius[i], @start_angle[i], @end_angle[i], @direction[i])
        ctx.stroke()

    draw_legend: (ctx, x1, x2, y1, y2) ->
      glyph_props = @glyph_props
      line_props = glyph_props.line_properties
      ctx.save()
      reference_point = @get_reference_point()
      if reference_point?
        glyph_settings = reference_point
        data_r = @distance([reference_point], 'x', 'radius', 'edge')[0]
        start_angle = -@glyph_props.select('start_angle', reference_point)
        end_angle = -@glyph_props.select('end_angle', reference_point)
      else
        glyph_settings = glyph_props
        start_angle = -0.1
        end_angle = -3.9
      direction = @glyph_props.select('direction', glyph_settings)
      direction = if direction == "clock" then false else true
      border = line_props.select(line_props.line_width_name, glyph_settings)
      ctx.beginPath()
      d = _.min([Math.abs(x2-x1), Math.abs(y2-y1)])
      d = d - 2 * border
      r = d / 2
      if data_r?
        r = if data_r > r then r else data_r
      ctx.arc((x1 + x2) / 2.0, (y1 + y2) / 2.0, r, start_angle,
        end_angle, direction)
      line_props.set(ctx, glyph_settings)
      if line_props.do_stroke
        line_props.set(ctx, glyph_settings)
        ctx.stroke()

      ctx.restore()

  class Arc extends Glyph.Model
    default_view: ArcView
    type: 'Glyph'

    display_defaults: () ->
      return _.extend(super(), {
        direction: 'anticlock'
        line_color: 'red'
        line_width: 1
        line_alpha: 1.0
        line_join: 'miter'
        line_cap: 'butt'
        line_dash: []
        line_dash_offset: 0
      })

  return {
    "Model": Arc,
    "View": ArcView,
  }
