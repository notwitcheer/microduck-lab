
import mujoco, numpy as np
from pathlib import Path
import arena
p = Path(arena.__file__).parent / "assets/robot/legs/robot_allcollisions.xml"
m = mujoco.MjModel.from_xml_path(str(p)); d = mujoco.MjData(m)
heads = [i for i in range(m.ngeom) if m.body(m.geom_bodyid[i]).name in ("neck","neck_pitch","yaw_roll_motion","jaw_soft","bearing_roll") and m.geom_type[i]==7]
for i in heads:
    print(i, m.body(m.geom_bodyid[i]).name, m.mesh(m.geom_dataid[i]).name)
def at(**q):
    mujoco.mj_resetData(m, d)
    for k, v in q.items(): d.qpos[m.joint(k).qposadr[0]] = v
    mujoco.mj_forward(m, d); return d.geom_xpos.copy()
b = at()
for j in ("neck_pitch","head_pitch","head_yaw","head_roll"):
    for v in (0.5,-0.5):
        a = at(**{j:v})
        print(j, v, {m.mesh(m.geom_dataid[i]).name: np.round(a[i]-b[i],3).tolist() for i in heads if np.abs(a[i]-b[i]).max()>1e-4})
print("rest centres", {m.mesh(m.geom_dataid[i]).name: np.round(b[i],3).tolist() for i in heads})
