// Original lens geometry. Run with: node assets/liquid-glass/build-lenses.mjs
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const output = path.dirname(fileURLToPath(import.meta.url));
const segments = 12;
const cross = (a,b) => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const sub = (a,b) => a.map((v,i)=>v-b[i]);
const dot = (a,b) => a.reduce((s,v,i)=>s+v*b[i],0);
const unit = a => {const length=Math.hypot(...a);return a.map(v=>v/length);};

function geometry(kind) {
  const vertices=[], faces=[];
  const vertex=(x,y,z,nx,ny,nz)=>{
    vertices.push({position:[x-.5,y-.5,z-.5],normal:[nx,ny,nz],uv:[x,y]});
    return vertices.length-1;
  };
  const triangle=(a,b,c)=>faces.push([a,b,c]);
  const quad=(a,b,c,d)=>{triangle(a,b,c);triangle(a,c,d);};
  const backRectangle=()=>quad(vertex(0,0,0,0,0,-1),vertex(0,1,0,0,0,-1),vertex(1,1,0,0,0,-1),vertex(1,0,0,0,0,-1));
  if (kind==='center') {
    quad(vertex(0,0,1,0,0,1),vertex(1,0,1,0,0,1),vertex(1,1,1,0,0,1),vertex(0,1,1,0,0,1));
    backRectangle();
  } else if (kind==='edge') {
    const rows=[];
    for(let i=0;i<=segments;i++) {
      const angle=i/segments*Math.PI/2, c=Math.cos(angle), s=Math.sin(angle);
      rows.push([vertex(1-c,0,s,-c,0,s),vertex(1-c,1,s,-c,0,s)]);
    }
    for(let i=0;i<segments;i++) quad(rows[i][0],rows[i+1][0],rows[i+1][1],rows[i][1]);
    backRectangle();
  } else if (kind==='corner') {
    const rings=[];
    for(let i=0;i<segments;i++) {
      const angle=i/segments*Math.PI/2, radial=Math.cos(angle), z=Math.sin(angle), ring=[];
      for(let j=0;j<=segments;j++) {
        const arc=j/segments*Math.PI/2, x=radial*Math.cos(arc), y=radial*Math.sin(arc);
        ring.push(vertex(1-x,1-y,z,-x,-y,z));
      }
      rings.push(ring);
    }
    for(let i=0;i<segments-1;i++) for(let j=0;j<segments;j++) quad(rings[i][j],rings[i][j+1],rings[i+1][j+1],rings[i+1][j]);
    const tip=vertex(1,1,1,0,0,1), back=vertex(1,1,0,0,0,-1), arc=[];
    for(let j=0;j<=segments;j++) {
      if(j<segments) triangle(rings[segments-1][j],rings[segments-1][j+1],tip);
      const a=j/segments*Math.PI/2;
      arc.push(vertex(1-Math.cos(a),1-Math.sin(a),0,0,0,-1));
    }
    for(let j=0;j<segments;j++) triangle(back,arc[j+1],arc[j]);
  } else throw Error('Unknown lens '+kind);
  return {vertices,faces};
}

function validate({vertices,faces},kind) {
  for(const v of vertices) {
    if([...v.position,...v.normal,...v.uv].some(n=>!Number.isFinite(n))) throw Error(kind+': non-finite vertex');
    if(Math.abs(Math.hypot(...v.normal)-1)>1e-6) throw Error(kind+': invalid normal');
  }
  for(const face of faces) {
    if(face.some(i=>!Number.isInteger(i)||i<0||i>=vertices.length)) throw Error(kind+': invalid triangle index');
    const [a,b,c]=face.map(i=>vertices[i]), normal=cross(sub(b.position,a.position),sub(c.position,a.position));
    if(Math.hypot(...normal)<1e-10) throw Error(kind+': degenerate triangle');
    const average=a.normal.map((n,i)=>n+b.normal[i]+c.normal[i]);
    if(dot(normal,average)<=0) throw Error(kind+': reversed triangle winding');
  }
  for(let axis=0;axis<3;axis++) {
    const values=vertices.map(v=>v.position[axis]);
    if(Math.abs(Math.min(...values)+.5)>1e-6||Math.abs(Math.max(...values)-.5)>1e-6) throw Error(kind+': incorrect unit bounds');
  }
}

function encode({vertices,faces}) {
  const signature=Buffer.from('version 2.00\n'), header=Buffer.alloc(12), vertexData=Buffer.alloc(vertices.length*40), faceData=Buffer.alloc(faces.length*12);
  header.writeUInt16LE(12,0);header[2]=40;header[3]=12;
  header.writeUInt32LE(vertices.length,4);header.writeUInt32LE(faces.length,8);
  vertices.forEach((v,index)=>{
    const p=index*40, values=[...v.position,...v.normal,...v.uv];
    values.forEach((value,j)=>vertexData.writeFloatLE(value,p+j*4));
    const tangent=unit(cross(Math.abs(v.normal[1])>.95?[1,0,0]:[0,1,0],v.normal));
    tangent.forEach((value,j)=>vertexData.writeInt8(Math.round(value*127),p+32+j));
    vertexData.writeInt8(127,p+35);
    vertexData.fill(255,p+36,p+40);
  });
  faces.forEach((face,index)=>face.forEach((value,j)=>faceData.writeUInt32LE(value,index*12+j*4)));
  return Buffer.concat([signature,header,vertexData,faceData]);
}

const manifest={version:1,description:'Original procedurally generated rounded lens patches. No third-party geometry.',meshes:{}};
for(const kind of ['center','edge','corner']) {
  const mesh=geometry(kind);validate(mesh,kind);
  const bytes=encode(mesh), filename=kind+'.mesh';
  fs.writeFileSync(path.join(output,filename),bytes);
  manifest.meshes[kind]={file:filename,vertices:mesh.vertices.length,triangles:mesh.faces.length,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
  console.log(`PASS ${kind}: valid unit bounds, normals, triangle indices and winding (${mesh.faces.length} triangles)`);
}
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
