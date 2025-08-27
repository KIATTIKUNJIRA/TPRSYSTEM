
// ---- Mock data shared across pages ----
export const PEOPLE = [
  { id:1, email:'admin@tripeera.com', first_name:'Admin', last_name:'One', company_id:1, role_y:'admin', status:'active' },
  { id:2, email:'atjimak@tripeera.com', first_name:'Atjimak', last_name:'K.', company_id:1, role_y:'user', status:'active' },
  { id:3, email:'kantithatk@tripeera.com', first_name:'Kantithat', last_name:'K.', company_id:1, role_y:'user', status:'active' },
  { id:4, email:'pak@tripeera.com', first_name:'Pak', last_name:'S.', company_id:1, role_y:'head', status:'active' },
];
export const COMPANIES = [{ id:1, name:'Tripira' }, { id:2, name:'Client A' }];
export const PROJECTS = [
  { id:101, name:'Client A Website Revamp', company_id:2, status:'active' },
  { id:102, name:'Internal HR Portal', company_id:1, status:'active' },
];
export let BOARD_COLUMNS = [
  { id:1001, project_id:101, name:'To Do', order_index:1, type:'status' },
  { id:1002, project_id:101, name:'In Progress', order_index:2, type:'status' },
  { id:1003, project_id:101, name:'Done', order_index:3, type:'status' },
  { id:2001, project_id:102, name:'To Do', order_index:1, type:'status' },
  { id:2002, project_id:102, name:'In Progress', order_index:2, type:'status' },
  { id:2003, project_id:102, name:'Done', order_index:3, type:'status' },
];
export let BOARD_ITEMS = [
  { id:9001, project_id:101, column_id:1001, title:'Design landing page', assignee_id:2, due_date:'2025-08-20', priority:'High', points:3, tags:['UI','ClientA'] },
  { id:9002, project_id:101, column_id:1002, title:'Build components', assignee_id:2, due_date:'2025-08-25', priority:'Medium', points:5, tags:['FE','React'] },
  { id:9003, project_id:101, column_id:1002, title:'QA checklist', assignee_id:3, due_date:'2025-08-22', priority:'Low', points:2, tags:['QA'] },
  { id:9004, project_id:101, column_id:1003, title:'Client kickoff', assignee_id:4, due_date:'2025-08-10', priority:'High', points:1, tags:['Meeting'] },
  { id:9101, project_id:102, column_id:2001, title:'Auth page', assignee_id:2, due_date:'2025-08-18', priority:'High', points:3, tags:['Security'] },
  { id:9102, project_id:102, column_id:2002, title:'Timesheet module', assignee_id:3, due_date:'2025-08-28', priority:'Medium', points:5, tags:['FE'] },
];
export const RATES = [
  { person_id:2, currency:'THB', rate_per_hour:900, effective_from:'2025-07-01' },
  { person_id:3, currency:'THB', rate_per_hour:700, effective_from:'2025-07-15' },
  { person_id:4, currency:'THB', rate_per_hour:1200, effective_from:'2025-06-01' },
];
export const TIMESHEETS = [
  { id:1, project_id:101, item_id:9001, person_id:2, date:'2025-08-12', hours:5, notes:'UX' },
  { id:2, project_id:101, item_id:9002, person_id:2, date:'2025-08-13', hours:6, notes:'Coding' },
  { id:3, project_id:101, item_id:9003, person_id:3, date:'2025-08-13', hours:4, notes:'Test' },
  { id:4, project_id:102, item_id:9102, person_id:3, date:'2025-08-11', hours:2, notes:'Module setup' },
];

export const companyName = (id)=> (COMPANIES.find(c=>c.id===id)?.name || '-');
export const personName = (id)=> { const p = PEOPLE.find(x=>x.id===id); return p? `${p.first_name} ${p.last_name}`:'-'; };
export const latestRate = (personId, atDate)=>{
  const d = new Date(atDate);
  return (RATES
    .filter(r=> r.person_id===personId && new Date(r.effective_from)<=d)
    .sort((a,b)=> new Date(b.effective_from)-new Date(a.effective_from))[0]?.rate_per_hour || 0);
};

export function renderNavbar(active){
  return `
  <nav class="navbar navbar-expand-lg bg-white border-bottom">
    <div class="container-fluid">
      <a class="navbar-brand" href="boards.html">TPR Digital Hub</a>
      <div class="navbar-nav flex-row gap-2">
        <a class="nav-link ${active==='boards'?'active':''}" href="boards.html">Boards</a>
        <a class="nav-link ${active==='people'?'active':''}" href="people.html">People</a>
        <a class="nav-link ${active==='timesheets'?'active':''}" href="timesheets.html">Timesheets</a>
        <a class="nav-link ${active==='rates'?'active':''}" href="rates.html">Rates</a>
      </div>
    </div>
  </nav>`;
}
