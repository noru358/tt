const form = document.getElementById('lead-form');
const message = document.getElementById('form-message');

form.addEventListener('submit', (event) => {
  event.preventDefault();
  const email = document.getElementById('email').value.trim();
  if (!email) return;
  const leads = JSON.parse(localStorage.getItem('opportunityRadarLeads') || '[]');
  leads.push({ email, createdAt: new Date().toISOString() });
  localStorage.setItem('opportunityRadarLeads', JSON.stringify(leads));
  message.textContent = '신청이 기록되었습니다. 실제 운영 시 이메일 수집 도구와 연결합니다.';
  form.reset();
});
