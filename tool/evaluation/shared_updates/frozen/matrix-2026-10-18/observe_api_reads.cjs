'use strict';
// Optional diagnostic hooks: original objects/pulls/cache policy stay intact.
// At most 4096 metadata rows and eight unmatched 512 KiB body texts per page.
function installReadObserver(){
 const nativeFetch=window.fetch,nativeParse=JSON.parse,nativeGetReader=ReadableStream.prototype.getReader,
  nativeRead=ReadableStreamDefaultReader.prototype.read,nativeCancel=ReadableStreamDefaultReader.prototype.cancel;
 const streams=new WeakMap(),readers=new WeakMap(),rows=[],ordinals=new Map();
 let droppedReads=0;
 const normalize=path=>path.replace(/\/\d+(?=\/|$)/g,'/:id');
 const target=path=>path.startsWith('/api/v1/')&&!path.startsWith('/api/v1/auth/')&&!path.startsWith('/api/v1/changes')&&!path.startsWith('/api/v1/media');
 window.fetch=function(input,init){
  const url=new URL(typeof input==='string'?input:input.url,location.href),method=(init?.method||input?.method||'GET').toUpperCase();
  if(method!=='GET'||!target(url.pathname))return Reflect.apply(nativeFetch,this,arguments);
  if(rows.length>=4096){droppedReads++;return Reflect.apply(nativeFetch,this,arguments);}
  const route=normalize(url.pathname),ordinal=(ordinals.get(route)||0)+1;ordinals.set(route,ordinal);
  const row={route,ordinal,startedAt:Date.now(),status:null,bodyBytes:0,readChunks:0,eof:false,readerError:null,cancelCalled:false,
    jsonValid:null,applicationJsonParsed:false,rootKeys:null,listCount:null,bodyLimitExceeded:false,_retain:true,_text:'',_decoder:new TextDecoder('utf-8',{fatal:true})};
  if(rows.filter(item=>item._retain).length>=8){row._retain=false;row._decoder=null;row.bodyEvidenceRetentionLimitExceeded=true;}
  rows.push(row);
  return Reflect.apply(nativeFetch,this,arguments).then(response=>{
   row.status=response.status;row.cacheControl=response.headers.get('cache-control');
   row.contentLength=response.headers.get('content-length');
   if(response.body)streams.set(response.body,row);else row.noBody=true;
   return response;
  });
 };
 ReadableStream.prototype.getReader=function(){const reader=Reflect.apply(nativeGetReader,this,arguments),row=streams.get(this);if(row)readers.set(reader,row);return reader;};
 ReadableStreamDefaultReader.prototype.read=function(){
  const result=Reflect.apply(nativeRead,this,arguments),row=readers.get(this);if(!row)return result;
  return result.then(chunk=>{
   try{
    if(chunk.done){
     row.eof=true;row.eofAt=Date.now();
     if(row._retain&&!row.bodyLimitExceeded){
      row._text+=row._decoder.decode();
      const data=nativeParse(row._text);row.jsonValid=true;row.rootKeys=data&&typeof data==='object'?Object.keys(data).sort().slice(0,16).map(key=>key.slice(0,80)):[];
      if(Array.isArray(data?.animals))row.listCount=data.animals.length;
      if(Array.isArray(data?.boxes))row.listCount=data.boxes.length;
      row._decoder=null;
     }
    }else{
     row.bodyBytes+=chunk.value.byteLength;row.readChunks++;
     if(row._retain&&row.bodyBytes<=512*1024)row._text+=row._decoder.decode(chunk.value,{stream:true});
     else if(row.bodyBytes>512*1024){row.bodyLimitExceeded=true;row._retain=false;row._text='';row._decoder=null;}
    }
   }catch(error){row.jsonValid=false;row.validationError=error.name;row._retain=false;row._text='';row._decoder=null;}
   return chunk;
  },error=>{row.readerError=error.name;row._retain=false;row._text='';row._decoder=null;throw error;});
 };
 ReadableStreamDefaultReader.prototype.cancel=function(){const row=readers.get(this);if(row){row.cancelCalled=true;row.cancelAfterEof=row.eof;row.cancelAt=Date.now();}return Reflect.apply(nativeCancel,this,arguments);};
 JSON.parse=function(text){
  const value=Reflect.apply(nativeParse,this,arguments);
  if(typeof text==='string'){
   const row=rows.find(row=>row.eof&&!row.applicationJsonParsed&&!row.bodyLimitExceeded&&row._text===text);
   if(row){row.applicationJsonParsed=true;row.applicationJsonParsedAt=Date.now();row._text='';row._decoder=null;row._retain=false;}
  }
  return value;
 };
 window.__tm230ReadSnapshot=()=>({droppedReads,records:rows.map(row=>Object.fromEntries(Object.entries(row).filter(([key])=>!key.startsWith('_'))))});
}
function correlateReadFailure(failure, records) {
  const read = records.find(row => row.route === failure.route && row.ordinal === failure.ordinal);
  if (!read) return {...failure, readEvidence: null};
  const result = {...failure, networkBodyOutcome: failure.bodyOutcome, readEvidence: read};
  if (read.readerError) result.bodyOutcome = 'actual-reader-error';
  else if (read.eof && read.jsonValid === true && !read.bodyLimitExceeded) result.bodyOutcome = 'actual-body-valid-json-read-to-eof';
  else if (read.eof && read.jsonValid === false) result.bodyOutcome = 'actual-body-invalid-json';
  result.applicationOutcome = read.applicationJsonParsed === true
    ? 'json-decoded-by-actual-application-consumer'
    : 'not-established-by-read-observer';
  return result;
}
module.exports = {installReadObserver, correlateReadFailure};
