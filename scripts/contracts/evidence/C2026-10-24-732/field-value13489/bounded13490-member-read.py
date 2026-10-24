from pathlib import Path
import runpy
r=Path.cwd();masked=runpy.run_path(str(r/'scripts/verify-context-fixture-initializers.py'))['masked']
for filename,var in [('function_expressions.slg','expressionIndex'),('entry_expressions.slg','entryExpressionIndex'),('control_region_expressions.slg','regionNodeIndex')]:
 p=r/'selfhost/llvm/text'/filename;text=p.read_text(encoding='utf-8');node={'expressionIndex':'expression','entryExpressionIndex':'entryExpression','regionNodeIndex':'regionNode'}[var]
 marker=f'    {node}.kind == 13 -> if {{';start=text.index(marker);brace=text.index('{',start);clean=masked(text);end=brace+1;depth=1
 while depth:depth+=(clean[end]=='{')-(clean[end]=='}');end+=1
 block=text[start:end];needle='"%v$('+var+')" -> print';n=block.count(needle);assert n>=3,(filename,n)
 block=block.replace(needle,var+' -> writeMemberStorageValueName(context, state)')
 # Direct synthetic-product/reference reads also assign the final result in
 # one formatted line; split only that assignment's left-hand side.
 lines=[];direct=0
 for line in block.splitlines():
  token='"  %v$('+var+') = '
  if token in line:
   indent=line[:len(line)-len(line.lstrip())];tail=line.split(token,1)[1]
   lines.extend([indent+'"  " -> print',indent+var+' -> writeMemberStorageValueName(context, state)',indent+'" = '+tail]);direct+=1
  else:lines.append(line)
 block='\n'.join(lines);last=block.rfind('}');owner='ownerIndex' if filename.startswith('control_') else 'functionIndex'
 post=f'''        context.ir[{var}] -> boundedArrayValueTypeId(context, state) => boundedMemberTypeId
        boundedMemberTypeId >= 0 -> if {{
            "v$({var})" -> emitBoundedArrayHandle("%v$({var})_bounded_value", boundedMemberTypeId, context, state)
        }}
    '''
 block=block[:last]+post+block[last:];p.write_text(text[:start]+block+text[end:],encoding='utf-8');print(filename,'storage names',n,'direct assignments',direct)
