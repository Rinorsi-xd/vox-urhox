'use strict';
const assert=require('node:assert/strict');
const anchor='function M.Step(v,contactSupport)\n';
const branch=`    if #v.spec.hovers==0 then
        v.hoverStates={}
        return {hovers=0,hoverCount=0,hoverForce=0,hoverSupport=0/(v.mass*9.81),
            hoverHeight=nil,hoverHeightTarget=nil,hoverHeightScale=v.hoverHeightScale or 1}
    end
`;
function candidate(source){
 const normalized=source.replaceAll('\r\n','\n');
 assert.equal(normalized.split(anchor).length,2,'Unique actual HoverControl.Step boundary');
 const inserted=normalized.replace(anchor,anchor+branch);
 assert.equal(inserted.replace(branch,''),normalized,'Nonempty implementation retained byte-for-byte after newline normalization');
 return source.includes('\r\n')?inserted.replaceAll('\n','\r\n'):inserted;
}
module.exports={candidate,branch};
