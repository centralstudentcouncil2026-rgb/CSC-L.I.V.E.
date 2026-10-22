(function () {
 'use strict';
 const eye='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/></svg>';
 const passwords=new WeakMap();
 function unwrap(card) {
  const content=card.querySelector(':scope > .login-card-content'); if(!content)return;
  const heading=content.querySelector(':scope > .login-heading');
  if(heading)heading.replaceWith(...heading.childNodes);
  content.replaceWith(...content.childNodes);
 }
 function enhance(form) {
  const live=form.id==='signInForm';
  const card=live?form.closest('.auth-panel'):form.closest('.login-card'); if(!card)return;
  if(live&&form.classList.contains('hidden')) { if(card.classList.contains('login-ui-refresh'))card.classList.remove('login-ui-refresh');unwrap(card);return; }
  if(!card.classList.contains('login-ui-refresh'))card.classList.add('login-ui-refresh');
  card.dataset.loginDesign=live?'live':form.id==='login-form'?'trace':'sync';
  let content=card.querySelector(':scope > .login-card-content');
  if(!content){
   content=document.createElement('div');content.className='login-card-content';
   content.append(...card.childNodes);card.append(content);
   const heading=document.createElement('div');heading.className='login-heading';
   const nodes=live?[content.querySelector(':scope > .live-login-eyebrow'),content.querySelector(':scope > .mb-6')]:[content.querySelector(':scope > .auth-eyebrow, :scope > .eyebrow'),content.querySelector(':scope > h2'),content.querySelector(':scope > p:not(.toast)')];
   const first=nodes.find(Boolean);if(first){content.insertBefore(heading,first);nodes.filter(Boolean).forEach(node=>heading.append(node));}
  }
  const password=form.querySelector('[data-csc-password]');
  if(password){
   let state=passwords.get(password);
   if(!state){
    password.id=password.id||'password-'+form.dataset.cscAccountScope;
    let parent=password.parentElement;
    if(parent.tagName==='LABEL'){
     const field=document.createElement('div');field.className='login-field';
     parent.before(field);field.append(parent);parent.htmlFor=password.id;
     const wrap=document.createElement('div');wrap.className='login-password';field.append(wrap);wrap.append(password);parent=wrap;
    }else parent.classList.add('login-password');
    const toggle=document.createElement('button');toggle.type='button';toggle.className='login-password-toggle';toggle.innerHTML=eye;
    toggle.setAttribute('aria-controls',password.id);toggle.setAttribute('aria-label','Show password');toggle.setAttribute('aria-pressed','false');
    toggle.addEventListener('click',()=>{const visible=password.type==='password';password.type=visible?'text':'password';toggle.setAttribute('aria-label',visible?'Hide password':'Show password');toggle.setAttribute('aria-pressed',String(visible));});
    parent.append(toggle);state={toggle,scope:form.dataset.cscAccountScope};passwords.set(password,state);
   }
   if(state.scope!==form.dataset.cscAccountScope){password.type='password';state.toggle.setAttribute('aria-label','Show password');state.toggle.setAttribute('aria-pressed','false');state.scope=form.dataset.cscAccountScope;}
  }
  if(live) for(const button of card.querySelectorAll('.signin-role-btn,.mode-btn'))button.setAttribute('aria-pressed',String(button.classList.contains('active')));
  const submit=form.querySelector('button[type="submit"]');
  form.setAttribute('aria-busy',String(!!submit?.disabled));
  for(const field of form.querySelectorAll('input'))if(!field.dataset.loginValidation){
   field.dataset.loginValidation='true';
   field.addEventListener('invalid',()=>field.setAttribute('aria-invalid','true'));
   field.addEventListener('input',()=>field.removeAttribute('aria-invalid'));
  }
  const error=card.querySelector('#login-error, .login-inline-error, #alertMessage');
  const hasError=!!(error?.textContent.trim()&&!error.closest('.hidden'));
  if(card.classList.contains('login-has-error')!==hasError)card.classList.toggle('login-has-error',hasError);
  if(error){error.id=error.id||'error-'+form.dataset.cscAccountScope;form.setAttribute('aria-describedby',error.id);}
 }
 function scan(){document.querySelectorAll('form[data-csc-account-scope="sync-admin"],form[data-csc-account-scope="trace-admin"],#signInForm').forEach(enhance);}
 let queued=false;
 function start(){scan();new MutationObserver(()=>{if(queued)return;queued=true;queueMicrotask(()=>{queued=false;scan();});}).observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class','disabled','data-csc-account-scope']});}
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
