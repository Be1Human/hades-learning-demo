"""Author an original stylized skull mesh in Blender; no downloaded model/assets.

Run: blender --background --python tools/author_skull_r01.py
Blender coordinates: Z up, -Y forward. GLB uses Godot Y up / +Z forward.
"""
from pathlib import Path
import bpy, math, random, json, hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
AUTHOR=ROOT/'authoring/skull-r01'
ASSETS=ROOT/'assets/characters/skull-r01'
for p in [AUTHOR,ASSETS]:p.mkdir(parents=True,exist_ok=True)
random.seed(41)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def active(obj):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
def apply(obj,modifier):
    active(obj);bpy.ops.object.modifier_apply(modifier=modifier.name)
def ellipsoid(name,location,scale,segments=48,rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=location)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return obj
def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    return obj
def unify(objects,name,voxel=.016):
    obj=join(objects,name)
    mod=obj.modifiers.new('Continuous sculpted bone','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True;apply(obj,mod)
    mod=obj.modifiers.new('Sculpt cleanup','SMOOTH');mod.factor=.65;mod.iterations=4;apply(obj,mod)
    return obj
def subtract(obj,cutter):
    mod=obj.modifiers.new('Carved '+cutter.name,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;apply(obj,mod)
    bpy.data.objects.remove(cutter,do_unlink=True)
def tube(name,points,radii,sides=10):
    verts=[];faces=[]
    for i,point in enumerate(points):
        p=Vector(point);direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        direction.normalize();u=direction.cross(Vector((0,0,1)))
        if u.length<.01:u=direction.cross(Vector((1,0,0)))
        u.normalize();v=direction.cross(u).normalized()
        radius=radii[i] if isinstance(radii,list) else radii
        for j in range(sides):
            a=j*math.tau/sides;verts.append(p+radius*(math.cos(a)*u+math.sin(a)*v))
        if i:
            for j in range(sides):
                a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides
                faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return obj
def material(name,color,emission=0):
    mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*color,1)
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.87
    if emission:
        bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
    else:
        vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='BonePaint'
        mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
    return mat

bone=material('Ivory bone · vertex painted',(.72,.60,.40))
teeth_mat=material('Aged enamel · vertex painted',(.91,.79,.56))
crack_mat=material('Recessed sutures · umber',(.075,.047,.038))
ember_mat=material('Ember soul eyes',(.65,.047,.004),2.0)
ember_core=material('Ember core',(.95,.38,.045),2.5)

# Continuous cranium and face mask: silhouette narrows at temples and maxilla.
crown=ellipsoid('Cranium',(0,.055,.205),(.49,.405,.49))
for vertex in crown.data.vertices:
    world=crown.matrix_world@vertex.co
    if world.z<.20:vertex.co.x*=.88+.12*max(0,(world.z+.28)/.48)
parts=[crown,ellipsoid('Frontal plate',(0,-.205,.245),(.36,.235,.31)),
       ellipsoid('Occipital ridge',(0,.369,.09),(.29,.074,.12)),
       ellipsoid('Maxilla',(0,-.235,-.215),(.30,.215,.19)),
       ellipsoid('Nasal bridge',(0,-.385,.09),(.074,.085,.22))]
for side in [-1,1]:
    parts.append(ellipsoid('Cheekbone',(side*.377,-.16,-.065),(.15,.17,.11)))
    parts.append(tube('Zygomatic arch',[(side*.32,-.285,-.10),(side*.43,-.21,-.08),(side*.47,-.06,-.045),(side*.415,.10,.04)], [.063,.061,.047,.053]))
    brow=ellipsoid('Heavy brow ridge',(side*.228,-.338,.266),(.218,.093,.058));brow.rotation_euler.y=side*math.radians(-14);parts.append(brow)
head=unify(parts,'Cranium')
for side in [-1,1]:
    eye=ellipsoid('Deep orbital cavity',(side*.232,-.357,.082),(.159,.231,.184),56,40)
    eye.rotation_euler.y=side*math.radians(-12)
    subtract(head,eye)
    cheek=ellipsoid('Temporal hollow',(side*.365,.005,-.22),(.146,.252,.155))
    subtract(head,cheek)

# A genuinely recessed heart/triangular nasal cavity, not a surface decal.
outline=[(-.042,.079),(.042,.079),(.091,-.065),(.078,-.145),(.019,-.178),(0,-.132),(-.019,-.178),(-.078,-.145),(-.091,-.065)]
vertices=[(x,y,z) for y in [-.68,-.12] for x,z in outline];n=len(outline)
faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('Nasal aperture');mesh.from_pydata(vertices,[],faces);mesh.update()
cutter=bpy.data.objects.new('Nasal aperture',mesh);bpy.context.collection.objects.link(cutter);subtract(head,cutter)
# Remesh the carved surfaces so tiny boolean slivers never reach the renderer.
remesh=head.modifiers.new('Clean orbital and nasal topology','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.011;remesh.use_smooth_shade=True;apply(head,remesh)
smooth=head.modifiers.new('Soften carved bone edges','SMOOTH');smooth.factor=.45;smooth.iterations=3;apply(head,smooth)
dec=head.modifiers.new('Readable game topology','DECIMATE');dec.ratio=.28;apply(head,dec)
head.data.materials.append(bone)

# U-shaped mandible with ascending rami. The mouth remains physically open.
path=[]
for i in range(29):
    a=-1.42+i*2.84/28
    path.append((.295*math.sin(a),-.026-.265*math.cos(a),-.493+.065*abs(math.sin(a))))
jaw_parts=[tube('Mandibular arch',path,.050,12),ellipsoid('Chin',(0,-.271,-.499),(.15,.079,.061))]
for side in [-1,1]:
    jaw_parts.append(tube('Ascending ramus',[(side*.292,-.063,-.43),(side*.354,.045,-.32),(side*.355,.052,-.13)], [.065,.065,.045],12))
    jaw_parts.append(ellipsoid('Jaw hinge',(side*.355,.052,-.125),(.052,.068,.056)))
jaw=unify(jaw_parts,'Mandible',.011)
dec=jaw.modifiers.new('Mandible topology','DECIMATE');dec.ratio=.40;apply(jaw,dec);jaw.data.materials.append(bone)
jaw_pivot=bpy.data.objects.new('JawPivot',None);bpy.context.collection.objects.link(jaw_pivot);jaw_pivot.location=(0,.052,-.125)
bpy.context.view_layer.update()
jaw.parent=jaw_pivot;jaw.matrix_parent_inverse=jaw_pivot.matrix_world.inverted()

def tooth(name,location,width,depth,length,angle,upper):
    # Crown tapers toward the cutting edge; bevels retain broad, painted planes.
    zsign=-1 if upper else 1;w=width/2;d=depth/2
    verts=[(-w,-d,0),(w,-d,0),(w,d,0),(-w,d,0),(-w*.78,-d*.74,zsign*length),(w*.78,-d*.74,zsign*length),(w*.60,d*.58,zsign*length),(-w*.60,d*.58,zsign*length)]
    faces=[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    if upper:faces=[tuple(reversed(f)) for f in faces]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.location=location;obj.rotation_euler.z=angle
    bevel=obj.modifiers.new('Rounded enamel edges','BEVEL');bevel.width=.011;bevel.segments=2;apply(obj,bevel)
    return obj
groups={True:[],False:[]}
for upper in [True,False]:
    for i in range(12):
        a=math.radians(-77+i*14);s=abs(math.sin(a))
        width=.061 if s<.5 else .073
        length=(.117 if upper else .092)+(.028 if .48<s<.72 else 0)
        if upper and i==3:length*=.75
        x=(.26 if upper else .249)*math.sin(a)
        y=(-.121 if upper else -.055)-(.263 if upper else .246)*math.cos(a)
        z=-.260-.012*s if upper else -.471+.02*s
        groups[upper].append(tooth(('Upper' if upper else 'Lower')+'Tooth%02d'%i,(x,y,z),width,.082,length,a,upper))
upper_teeth=join(groups[True],'UpperTeeth');upper_teeth.data.materials.append(teeth_mat)
lower_teeth=join(groups[False],'LowerTeeth');lower_teeth.data.materials.append(teeth_mat)
lower_teeth.parent=jaw_pivot;lower_teeth.matrix_parent_inverse=jaw_pivot.matrix_world.inverted()

# Rays inside the carved orbits. Tiny geometry, controlled runtime emissive material.
eyes=[]
for side in [-1,1]:
    eye=ellipsoid('EmberEye'+('L' if side<0 else 'R'),(side*.229,-.200,.075),(.047,.034,.059),24,16)
    eye.rotation_euler.y=side*math.radians(-12);eye.data.materials.append(ember_mat);eyes.append(eye)
    core=ellipsoid('EmberCore'+('L' if side<0 else 'R'),(side*.229,-.231,.077),(.018,.009,.029),16,12)
    core.rotation_euler.y=side*math.radians(-12);core.data.materials.append(ember_core);eyes.append(core)

# Fine sutures are projected onto the actual sculpted surface.
bpy.context.view_layer.update()
bvh=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
world_to_local=head.matrix_world.inverted()
def project_surface(x,z,rear=False):
    origin=world_to_local@Vector((x,2 if rear else -2,z));direction=head.matrix_world.inverted().to_3x3()@Vector((0,-1 if rear else 1,0))
    hit,normal,_,_=bvh.ray_cast(origin,direction)
    return head.matrix_world@(hit+normal*.0012) if hit is not None else None
crack_paths=[[(0,.653),(-.025,.59),(.009,.558),(-.031,.51),(-.012,.464),(-.054,.415),(-.025,.374)],
             [(-.014,.514),(-.071,.52),(-.101,.548)],
             [(-.052,.416),(-.107,.394),(-.116,.36)],
             [(.283,.415),(.266,.38),(.295,.338),(.275,.315)]]
rear_paths=[[(0,.67),(.016,.61),(-.014,.57),(.011,.52),(-.012,.47),(.005,.42),(0,.36)],
            [(-.005,.38),(-.047,.36),(-.07,.32),(-.115,.31),(-.15,.265),(-.21,.253),(-.25,.21),(-.32,.19)],
            [(.006,.37),(.05,.35),(.073,.318),(.126,.309),(.158,.271),(.212,.261),(.256,.22),(.315,.20)]]
cracks=[]
for rear,paths in [(False,crack_paths),(True,rear_paths)]:
    for i,path in enumerate(paths):
        dense=[]
        for a,b in zip(path,path[1:]):
            for step in range(5):dense.append((a[0]+(b[0]-a[0])*step/5,a[1]+(b[1]-a[1])*step/5))
        dense.append(path[-1])
        points=[p for x,z in dense if (p:=project_surface(x,z,rear)) is not None]
        if len(points)>1:cracks.append(tube('Bone suture '+str(i),points,.0025,5))
cracks=join(cracks,'BoneSutures');cracks.data.materials.append(crack_mat)

# Coarse painted tonal masses and contact shading, stored as editable vertex colors.
all_bone=[head,jaw,upper_teeth,lower_teeth]
bpy.context.view_layer.update()
world_vertices=[];triangles=[]
for obj in all_bone:
    obj.data.calc_loop_triangles();offset=len(world_vertices)
    world_vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    triangles.extend(tuple(offset+i for i in t.vertices) for t in obj.data.loop_triangles)
ao_tree=BVHTree.FromPolygons(world_vertices,triangles,all_triangles=True)
for obj in all_bone+[cracks]:
    attribute=obj.data.color_attributes.new(name='BonePaint',type='FLOAT_COLOR',domain='CORNER')
    obj.data.color_attributes.active_color=attribute
    enamel=obj in [upper_teeth,lower_teeth]
    for polygon in obj.data.polygons:polygon.use_smooth=obj in [head,jaw]
    for vertex in obj.data.vertices:
        p=obj.matrix_world@vertex.co;normal=(obj.matrix_world.to_3x3()@vertex.normal).normalized()
        if obj==cracks:color=(.072,.044,.032)
        else:
            up=max(0,min(1,(p.z+.55)/1.15));wave=math.sin(p.x*37+p.z*18)*math.sin(p.y*31-p.z*8)
            occluded=0
            tangent=normal.cross(Vector((0,0,1)))
            if tangent.length<.1:tangent=normal.cross(Vector((0,1,0)))
            tangent.normalize();bitangent=normal.cross(tangent)
            for i in range(10):
                a=i*2.39996;r=.70 if i%2 else .45
                direction=(normal*.68+tangent*math.cos(a)*r+bitangent*math.sin(a)*r).normalized()
                hit,_,_,distance=ao_tree.ray_cast(p+normal*.003,direction,.34)
                if hit is not None:occluded+=max(.2,1-distance/.34)
            shade=1-.063*occluded
            base=Vector((.48,.38,.235) if enamel else (.24+.16*up,.17+.145*up,.09+.105*up))
            broad=math.sin(p.x*12+p.z*9)*math.sin(p.y*11-p.z*6)
            base*=shade*(1+.065*wave+.095*broad)
            # Orbital and nasal depth keeps the glow embedded in dark cavities.
            if obj==head:
                cavity=0
                for side in [-1,1]:
                    ellipse=((p.x-side*.232)/.18)**2+((p.z-.082)/.205)**2
                    edge=max(0,min(1,(1.12-ellipse)/.26))
                    depth=max(0,min(1,(p.y+.37)/.105))
                    cavity=max(cavity,edge*depth)
                nose=max(0,min(1,(.11-abs(p.x))/.025))*max(0,min(1,(.13-p.z)/.055))*max(0,min(1,(p.z+.23)/.07))*max(0,min(1,(p.y+.38)/.12))
                cavity=max(cavity,nose)
                # Only face hollows get soot. The rear cranium retains bone paint.
                cavity*=max(0,min(1,(-.015-p.y)/.05))
                base*=1-.91*cavity
            color=tuple(base)
        # Cached per-vertex value copied to all polygon corners below.
        if vertex.index==0:colors={}
        colors[vertex.index]=(*color,1)
    for loop in obj.data.loops:attribute.data[loop.index].color=colors[loop.vertex_index]

# Preserve authored object transforms, export only the model collection.
model_objects=all_bone+[jaw_pivot,cracks]+eyes
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for obj in model_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=head
triangles_count=0
for obj in model_objects:
    if obj.type=='MESH':obj.data.calc_loop_triangles();triangles_count+=len(obj.data.loop_triangles)
bpy.ops.wm.save_as_mainfile(filepath=str(AUTHOR/'skull-r01.blend'))
options={'filepath':str(ASSETS/'skull.glb'),'export_format':'GLB','use_selection':True,'export_apply':True,'export_yup':True,'export_materials':'EXPORT'}
props=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
if 'export_colors' in props:options['export_colors']=True
if 'export_vertex_color' in props:options['export_vertex_color']='MATERIAL'
bpy.ops.export_scene.gltf(**options)
manifest={'revision':'skull-r01','authoring':'Original scripted Blender sculpt; no downloaded skull model, texture, or original-game extraction.',
 'axis':'Godot Y up, +Z forward','triangles':triangles_count,'mesh_objects':len([o for o in model_objects if o.type=='MESH']),
 'features':['continuous sculpted cranium','carved orbital and nasal cavities','zygomatic arches','separate hinged mandible','24 individually shaped teeth','projected fine sutures','vertex-painted bone and baked contact tones','embedded ember eyes'],
 'jaw_node':'JawPivot','asset_sha256':hashlib.sha256((ASSETS/'skull.glb').read_bytes()).hexdigest(),
 'tool_version':bpy.app.version_string,'runtime_asset':'assets/characters/skull-r01/skull.glb'}
(ASSETS/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(AUTHOR/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('SKULL_ASSET_READY',json.dumps(manifest),flush=True)
