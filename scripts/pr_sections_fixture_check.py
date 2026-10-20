#!/usr/bin/env python3
"""Hermetic HA#351 contract, resolver, body and configuration fixtures."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import pr_sections as p


class Sections(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cat = p.catalogue()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ha351-')
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / 'nen').mkdir()

    def resolve(self, kind='process', jobs=('machinery',), facts=('policy-hit',), cat=None):
        return p.resolve(cat or self.cat, self.repo, kind, jobs, set(facts))

    def body(self, report):
        rows = {r['id']: r for r in self.cat['sections'] + self.cat['footer']}
        return '\n\n'.join('#' * rows[i]['level'] + ' ' + rows[i]['glyph'] + ' ' +
                             (rows[i]['title'] if isinstance(rows[i]['title'], str) else rows[i]['title']['process'])
                             + '\n\nFilled.' for i in report['ids'] + report['footer']) + '\n'

    def config(self, value):
        (self.repo / 'nen/workflow.json').write_text(json.dumps({'pr': {'sections': value}}))

    def test_every_cell_and_taxonomy_job(self):
        for cell, ids in self.cat['variants'].items():
            kind, family = cell.split('.')
            result = self.resolve(kind, self.cat['families'][family], ('policy-hit','evidence'))
            self.assertEqual(result['ids'], ids, cell)
            self.assertLessEqual(len(ids), 7)
        jobs = [j for entries in self.cat['families'].values() for j in entries]
        self.assertEqual(len(jobs), 39)
        self.assertEqual(len(set(jobs)), 39)

    def test_fold_distinct_count_precedence_and_no_issue(self):
        self.assertEqual(p.fold(self.cat, []), 'build')
        self.assertEqual(p.fold(self.cat, ['release','machinery']), 'release')
        self.assertEqual(p.fold(self.cat, ['schema','machinery','prose-authoring']), 'maintain')
        self.assertEqual(p.fold(self.cat, ['review','review','documentation']), 'verify')
        with self.assertRaises(ValueError):
            p.fold(self.cat, ['imaginary'])

    def test_run_facts_and_reserved_footer(self):
        report = self.resolve(facts=())
        self.assertNotIn('across', report['ids'])
        self.assertNotIn('delivery', report['footer'])
        report = self.resolve(facts=('policy-hit','economics'))
        self.assertEqual(report['ids'], ['changes','why','how','improves','across','verify','economics'])
        self.assertEqual(self.resolve('unknown')['ids'], ['changes','why','how','improves','verify'])
        self.assertNotIn('evidence', self.resolve('product', ('implementation',), facts=())['ids'])
        self.assertIn('evidence', self.resolve('product', ('implementation',), facts=('evidence',))['ids'])

    def test_consumer_cell_ownership_and_invalid_unused_cells(self):
        chosen = ['changes','why','improves','verify']
        self.config({'max':7,'variants':{'process.maintain':chosen}})
        self.assertEqual(self.resolve()['ids'], chosen)
        for value in ({'max':8}, {'max':True}, {'variants':{'library.fix':['unknown']}},
                      {'variants':{'invalid.cell':chosen}}, {'variants':{'process.fix':['why','verify']}}):
            self.config(value)
            with self.assertRaises(ValueError):
                self.resolve()
        self.config({'max':5})
        with self.assertRaises(ValueError):
            self.resolve()

    def test_symlink_workflow_refused(self):
        target = self.repo / 'outside.json'
        target.write_text('{}')
        (self.repo/'nen/workflow.json').symlink_to(target)
        with self.assertRaises(ValueError):
            self.resolve()

    def test_exact_headings_glyphs_order_and_final_footer(self):
        report = self.resolve()
        body = self.body(report)
        self.assertEqual(p.check(self.cat, body, report['requirements'], 7)[0], [])
        for bad in (body+'\n## Surprise\n', body.replace('## 🧭 Why','## 🧭 WHY').replace('## 🛠️ How','## Wrong'),
                    body.replace('## 🧭 Why','## 🛠️ How',1), body+'\n## 🧭 Why\n'):
            findings, _ = p.check(self.cat, bad, report['requirements'], 7)
            self.assertTrue(findings)
            self.assertTrue(any('line ' in f for f in findings))
        self.assertTrue(any('missing heading' in f for f in p.check(self.cat,body.replace('## 🧭 Why','### 🧭 Why'),report['requirements'],7)[0]))

    def test_eighth_reader_named(self):
        report = self.resolve(facts=('policy-hit','economics'))
        extra = p.pattern(next(r for r in self.cat['sections'] if r['id']=='rollout'), 'process')
        req = report['requirements'][:7]+[extra]+report['requirements'][7:]
        body = self.body(report).replace('## 📋 Completion checklist','## 🚀 Rollout & rollback\n\nOK\n\n## 📋 Completion checklist')
        errors, _ = p.check(self.cat,body,req,7)
        self.assertTrue(any('count exceeds max 7' in e and 'Rollout' in e for e in errors))

    def test_fences_comments_and_invalid_opening_fence(self):
        report = self.resolve()
        body = self.body(report)
        masked = '\n<!--\n## Phantom\n-->\n\n~~~markdown\n## Phantom\n~~~\n\n```mermaid\n## Phantom\n```\n'
        self.assertEqual(p.check(self.cat,body+masked,report['requirements'],7)[0], [])
        errors, _ = p.check(self.cat,body+'\n```bad`info\n## Phantom\n',report['requirements'],7)
        self.assertTrue(any('Phantom' in e for e in errors))

    def test_prose_warning_only_tables_and_diagrams_excluded(self):
        report = self.resolve()
        body = self.body(report).replace('Filled.', 'word '*151, 1)
        errors, warnings = p.check(self.cat, body, report['requirements'], 7)
        self.assertFalse(errors)
        self.assertEqual(len(warnings),1)
        self.assertIn('151 prose words',warnings[0])
        body = self.body(report).replace('Filled.','| A | B |\n|---|---|\n| '+('word '*200)+' | data |\n\n```mermaid\n'+('word '*200)+'\n```',1)
        self.assertEqual(p.check(self.cat,body,report['requirements'],7),([],[]))

    def test_catalogue_unknown_cell_and_duplicate_job_refused(self):
        # A fully copied catalogue is data; no executable fixture is loaded from it.
        import shutil
        for rel in ('contracts','templates/pr-body'):
            shutil.copytree(p.ROOT/rel,self.repo/rel)
        cat = copy.deepcopy(self.cat)
        cat['variants']['product.fix'].append('imaginary')
        (self.repo/'contracts/pr-sections.json').write_text(json.dumps(cat))
        with self.assertRaises(ValueError):
            p.catalogue(self.repo)
        cat = copy.deepcopy(self.cat)
        cat['families']['canon'].append('machinery')
        (self.repo/'contracts/pr-sections.json').write_text(json.dumps(cat))
        with self.assertRaises(ValueError):
            p.catalogue(self.repo)

    def test_cli_exit_codes_and_warning(self):
        report = self.resolve()
        body = self.body(report)
        body_file, req = self.repo/'body.md', self.repo/'requirements.json'
        resolver = subprocess.run(['bash',str(p.ROOT/'scripts/pr_sections_resolve.sh'),
            '--repo',str(self.repo),'--kind','process','--jobs','machinery','--policy-hit',
            '--out',str(req)],capture_output=True,text=True)
        self.assertEqual(resolver.returncode,0,resolver.stderr)
        self.assertEqual(json.loads(req.read_text()),report['requirements'])
        command = ['bash',str(p.ROOT/'scripts/pr_body_sections_check.sh'),'--body',str(body_file),
                   '--requirements',str(req),'--max','7']
        for value, code, text in ((body,0,'satisfied'),(body+'\n## Surprise\n',1,'Surprise'),
                                  (body.replace('Filled.','word '*151,1),0,'151 prose words')):
            body_file.write_text(value)
            result = subprocess.run(command,capture_output=True,text=True)
            self.assertEqual(result.returncode,code,result.stdout+result.stderr)
            self.assertIn(text,result.stdout)
        body_file.write_text('Preamble\n\n'+body)
        self.assertTrue(p.check(self.cat,body_file.read_text(),report['requirements'],7)[0])
        self.assertTrue(p.check(self.cat,body+'\nSurprise\n---\n',report['requirements'],7)[0])

    def test_fill_all_cells_and_preserve_consumer_override(self):
        script = p.ROOT/'scripts/config_values.sh'
        (self.repo/'nen/workflow.json').write_text(json.dumps({'review': {'scopes': {}}})+'\n')
        for f in ('gates.json','contract.json'):
            (self.repo/'nen'/f).write_text('{}\n')
        def run(*args):
            result = subprocess.run(['bash',str(script),*args,'--repo',str(self.repo)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            return result.stdout
        run('fill')
        workflow = json.loads((self.repo/'nen/workflow.json').read_text())
        sections = workflow['pr']['sections']
        self.assertEqual(sections['variants'],self.cat['variants'])
        self.assertEqual(sections['max'],7)
        for row in self.cat['sections']+self.cat['footer']:
            self.assertIn(row['id']+' — ',workflow['pr']['$sections'])
        sections['variants']['process.canon']=['changes','why','improves','verify']
        (self.repo/'nen/workflow.json').write_text(json.dumps(workflow))
        self.assertIn('consumer value',run('diagnose'))
        run('fill')
        self.assertEqual(json.loads((self.repo/'nen/workflow.json').read_text())['pr']['sections'],sections)


if __name__ == '__main__':
    unittest.main(verbosity=2)
