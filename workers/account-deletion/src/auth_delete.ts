export async function deleteAuthUser(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<void> {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${opts.projectId}/accounts:delete`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${opts.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ localId: opts.uid }),
    },
  );
  if (res.status === 404) return;
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`auth_delete_failed:${res.status}:${text.slice(0, 300)}`);
  }
}
